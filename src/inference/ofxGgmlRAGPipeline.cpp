#include "inference/ofxGgmlRAGPipeline.h"

#include "core/ofxGgmlMetrics.h"

#ifndef OFXGGML_HEADLESS_STUBS
#include "ofMain.h"
#endif

#include <algorithm>
#include <cmath>
#include <cctype>
#include <chrono>
#include <limits>
#include <sstream>
#include <unordered_map>
#include <unordered_set>

namespace {

std::string trimCopy(const std::string & text) {
	const auto begin = std::find_if_not(
		text.begin(),
		text.end(),
		[](unsigned char ch) { return std::isspace(ch) != 0; });
	const auto end = std::find_if_not(
		text.rbegin(),
		text.rend(),
		[](unsigned char ch) { return std::isspace(ch) != 0; }).base();
	if (begin >= end) {
		return {};
	}
	return std::string(begin, end);
}

std::string toLowerCopy(const std::string & text) {
	std::string lowered = text;
	std::transform(
		lowered.begin(),
		lowered.end(),
		lowered.begin(),
		[](unsigned char ch) { return static_cast<char>(std::tolower(ch)); });
	return lowered;
}

// Tokenize text into lowercase word tokens, stripping punctuation.
std::vector<std::string> tokenize(const std::string & text) {
	std::vector<std::string> tokens;
	std::string current;
	for (unsigned char ch : text) {
		if (std::isalnum(ch) != 0) {
			current.push_back(static_cast<char>(std::tolower(ch)));
		} else {
			if (!current.empty()) {
				tokens.push_back(std::move(current));
				current.clear();
			}
		}
	}
	if (!current.empty()) {
		tokens.push_back(std::move(current));
	}
	return tokens;
}

// Very short common words to skip when scoring.
const std::unordered_set<std::string> & stopWords() {
	static const std::unordered_set<std::string> kStopWords = {
		"a", "an", "the", "is", "it", "in", "on", "at", "to", "of",
		"and", "or", "for", "with", "as", "by", "be", "are", "was",
		"that", "this", "which", "from", "not", "but", "so", "if"
	};
	return kStopWords;
}

std::vector<std::string> dedupeQueries(const std::vector<std::string> & queries) {
	std::vector<std::string> out;
	std::unordered_set<std::string> seen;
	for (const auto & query : queries) {
		const std::string trimmed = trimCopy(query);
		if (trimmed.empty()) {
			continue;
		}
		const std::string normalized = toLowerCopy(trimmed);
		if (!seen.insert(normalized).second) {
			continue;
		}
		out.push_back(trimmed);
	}
	return out;
}

std::vector<std::string> buildRefinedQueries(
	const std::string & query,
	size_t maxAdditionalQueries) {
	std::vector<std::string> refined;
	if (maxAdditionalQueries == 0) {
		return refined;
	}

	const auto tokens = tokenize(query);
	std::vector<std::string> filtered;
	filtered.reserve(tokens.size());
	for (const auto & token : tokens) {
		if (token.size() < 4 || stopWords().find(token) != stopWords().end()) {
			continue;
		}
		filtered.push_back(token);
	}
	if (!filtered.empty()) {
		std::ostringstream focused;
		for (size_t i = 0; i < filtered.size(); ++i) {
			if (i > 0) {
				focused << ' ';
			}
			focused << filtered[i];
		}
		refined.push_back(focused.str());
	}
	if (refined.size() < maxAdditionalQueries && filtered.size() >= 2) {
		refined.push_back(filtered.front() + " " + filtered.back());
	}
	if (refined.size() > maxAdditionalQueries) {
		refined.resize(maxAdditionalQueries);
	}
	return dedupeQueries(refined);
}

float clampUnit(float value) {
	return std::max(0.0f, std::min(1.0f, value));
}

float lexicalScoreForQueries(
	const ofxGgmlRAGChunk & chunk,
	const std::vector<std::string> & queries) {
	float best = 0.0f;
	for (const auto & query : queries) {
		best = std::max(best, ofxGgmlRAGPipeline::scoreChunk(chunk, query));
	}
	return best;
}

float qualityScoreForChunk(
	const ofxGgmlRAGChunk & chunk,
	const std::vector<std::string> & queries) {
	const std::string loweredText = toLowerCopy(chunk.text);
	float score = 0.18f;

	if (!chunk.sourceLabel.empty()) {
		score += 0.08f;
	}
	if (!chunk.sourceUri.empty()) {
		score += 0.06f;
	}
	if (chunk.crawlDepth >= 0) {
		score += std::max(0.0f, 0.10f - static_cast<float>(chunk.crawlDepth) * 0.02f);
	}
	if (chunk.sourceByteSize > 512) {
		score += 0.04f;
	}
	score += clampUnit(chunk.sourceQualityHint) * 0.16f;

	const size_t length = chunk.text.size();
	if (length >= 180 && length <= 950) {
		score += 0.18f;
	} else if (length >= 90) {
		score += 0.10f;
	}

	size_t navigationHits = 0;
	for (const std::string marker : {"cookie", "privacy", "terms", "menu", "navigation"}) {
		if (loweredText.find(marker) != std::string::npos) {
			++navigationHits;
		}
	}
	score -= std::min(0.20f, static_cast<float>(navigationHits) * 0.05f);

	size_t topicalHits = 0;
	for (const auto & query : queries) {
		for (const auto & token : tokenize(query)) {
			if (token.size() < 4 || stopWords().find(token) != stopWords().end()) {
				continue;
			}
			if (loweredText.find(token) != std::string::npos) {
				++topicalHits;
			}
		}
	}
	score += std::min(0.18f, static_cast<float>(topicalHits) * 0.02f);
	return clampUnit(score);
}

std::vector<float> computeSemanticScores(
	const ofxGgmlInference & inference,
	const std::string & embeddingModelPath,
	const ofxGgmlEmbeddingSettings & embeddingSettings,
	const std::vector<std::string> & queries,
	const std::vector<ofxGgmlRAGChunk> & chunks,
	bool * usedSemanticRanking) {
	if (usedSemanticRanking) {
		*usedSemanticRanking = false;
	}
	std::vector<float> semanticScores(chunks.size(), 0.0f);
	if (embeddingModelPath.empty() || queries.empty() || chunks.empty()) {
		return semanticScores;
	}

	const auto queryEmbeddings = inference.embedBatch(
		embeddingModelPath,
		queries,
		embeddingSettings);
	if (queryEmbeddings.size() != queries.size()) {
		return semanticScores;
	}

	std::vector<std::string> chunkTexts;
	chunkTexts.reserve(chunks.size());
	for (const auto & chunk : chunks) {
		chunkTexts.push_back(chunk.text);
	}
	const auto chunkEmbeddings = inference.embedBatch(
		embeddingModelPath,
		chunkTexts,
		embeddingSettings);
	if (chunkEmbeddings.size() != chunks.size()) {
		return semanticScores;
	}

	bool anySemantic = false;
	for (size_t chunkIndex = 0; chunkIndex < chunks.size(); ++chunkIndex) {
		if (!chunkEmbeddings[chunkIndex].success ||
			chunkEmbeddings[chunkIndex].embedding.empty()) {
			continue;
		}
		float best = 0.0f;
		for (const auto & queryEmbedding : queryEmbeddings) {
			if (!queryEmbedding.success || queryEmbedding.embedding.empty()) {
				continue;
			}
			best = std::max(
				best,
				ofxGgmlEmbeddingIndex::cosineSimilarity(
					queryEmbedding.embedding,
					chunkEmbeddings[chunkIndex].embedding));
		}
		if (best > 0.0f) {
			anySemantic = true;
			semanticScores[chunkIndex] = best;
		}
	}

	if (usedSemanticRanking) {
		*usedSemanticRanking = anySemantic;
	}
	return semanticScores;
}

/// Call the llama-server /rerank endpoint and return per-document relevance
/// scores. Returns an empty vector if the call fails or the feature is
/// compiled out (headless mode).
std::vector<float> rerankViaServer(
	const std::string & serverUrl,
	const std::string & model,
	const std::string & query,
	const std::vector<ofxGgmlRAGChunk> & chunks) {
	std::vector<float> scores(chunks.size(), 0.0f);
	if (serverUrl.empty() || query.empty() || chunks.empty()) {
		return scores;
	}
#ifdef OFXGGML_HEADLESS_STUBS
	(void)model;
	return scores;
#else
	// Build base URL: strip any path suffix, append /rerank
	std::string baseUrl = serverUrl;
	auto stripSuffix = [&](const std::string & suffix) {
		if (baseUrl.size() >= suffix.size() &&
			baseUrl.compare(baseUrl.size() - suffix.size(), suffix.size(), suffix) == 0) {
			baseUrl.erase(baseUrl.size() - suffix.size());
		}
	};
	stripSuffix("/v1/chat/completions");
	stripSuffix("/chat/completions");
	stripSuffix("/v1/embeddings");
	stripSuffix("/embeddings");
	if (!baseUrl.empty() && baseUrl.back() == '/') {
		baseUrl.pop_back();
	}
	const std::string rerankUrl = baseUrl + "/rerank";

	try {
		ofJson payload;
		payload["query"] = query;
		if (!model.empty()) {
			payload["model"] = model;
		}
		ofJson docs = ofJson::array();
		for (const auto & chunk : chunks) {
			docs.push_back(chunk.text);
		}
		payload["documents"] = docs;

		ofHttpRequest httpRequest(rerankUrl, "rag-rerank");
		httpRequest.method = ofHttpRequest::POST;
		httpRequest.body = payload.dump();
		httpRequest.contentType = "application/json";
		httpRequest.headers["Accept"] = "application/json";
		httpRequest.timeoutSeconds = 60;

		ofURLFileLoader loader;
		const ofHttpResponse response = loader.handleRequest(httpRequest);
		if (response.status < 200 || response.status >= 300) {
			return scores;
		}

		const ofJson parsed = ofJson::parse(response.data.getText());
		const auto & results = parsed.contains("results") ? parsed["results"] : parsed;
		if (!results.is_array()) {
			return scores;
		}
		for (const auto & item : results) {
			if (!item.is_object()) {
				continue;
			}
			const int index = item.value("index", -1);
			const float relevance = item.value("relevance_score",
				item.value("score", 0.0f));
			if (index >= 0 && static_cast<size_t>(index) < scores.size()) {
				scores[static_cast<size_t>(index)] = relevance;
			}
		}
	} catch (...) {
	}
	return scores;
#endif
}

} // namespace

// ---------------------------------------------------------------------------
// ofxGgmlRAGPipeline
// ---------------------------------------------------------------------------

void ofxGgmlRAGPipeline::addDocument(const ofxGgmlRAGDocument & doc) {
	m_documents.push_back(doc);
	invalidateRetrievalCache();
}

void ofxGgmlRAGPipeline::addTextDocument(
	const std::string & content,
	const std::string & id,
	const std::string & label,
	const std::string & uri) {
	ofxGgmlRAGDocument doc;
	doc.content = content;
	doc.id = id.empty()
		? std::string("doc-") + std::to_string(m_documents.size() + 1)
		: id;
	doc.sourceLabel = label;
	doc.sourceUri = uri;
	m_documents.push_back(std::move(doc));
	invalidateRetrievalCache();
}

void ofxGgmlRAGPipeline::clearDocuments() {
	m_documents.clear();
	invalidateRetrievalCache();
}

size_t ofxGgmlRAGPipeline::documentCount() const {
	return m_documents.size();
}

void ofxGgmlRAGPipeline::clearRetrievalCache() {
	invalidateRetrievalCache();
}

ofxGgmlInference & ofxGgmlRAGPipeline::getInference() {
	return m_inference;
}

const ofxGgmlInference & ofxGgmlRAGPipeline::getInference() const {
	return m_inference;
}

ofxGgmlRAGRetrievalResult ofxGgmlRAGPipeline::retrieve(
	const ofxGgmlRAGQuery & query) const {
	const auto start = std::chrono::steady_clock::now();
	ofxGgmlRAGRetrievalResult result;
	if (trimCopy(query.query).empty()) {
		result.error = "RAG query is empty.";
		return result;
	}
	if (m_documents.empty()) {
		result.error = "No documents have been added to the RAG pipeline.";
		return result;
	}

	const std::string cacheKey = buildRetrievalCacheKey(query);
	if (query.enableRetrievalCache) {
		std::lock_guard<std::mutex> lock(m_retrievalCacheMutex);
		const auto it = m_retrievalCache.find(cacheKey);
		if (it != m_retrievalCache.end()) {
			m_retrievalCacheLru.remove(cacheKey);
			m_retrievalCacheLru.push_front(cacheKey);
			result = it->second.result;
			result.cacheHit = true;
			ofxGgmlMetrics::getInstance().recordCacheHit("rag.retrieval");
			return result;
		}
	}
	ofxGgmlMetrics::getInstance().recordCacheMiss("rag.retrieval");

	const size_t chunkSize = std::max(size_t(64), query.chunkSize);
	const size_t overlap = std::min(query.chunkOverlap, chunkSize / 2);

	std::vector<std::string> candidateQueries = {query.query};
	if (query.allowQueryRefinement) {
		for (const auto & variant : query.queryVariants) {
			candidateQueries.push_back(variant);
		}
		const auto refined = buildRefinedQueries(query.query, query.maxRefinementSteps);
		candidateQueries.insert(candidateQueries.end(), refined.begin(), refined.end());
	}
	candidateQueries = dedupeQueries(candidateQueries);
	result.queriesUsed = candidateQueries;
	if (candidateQueries.size() > 1) {
		result.refinementCount = candidateQueries.size() - 1;
	}

	std::vector<ofxGgmlRAGChunk> allChunks;
	for (const auto & doc : m_documents) {
		auto docChunks = chunkDocument(doc, chunkSize, overlap);
		allChunks.insert(
			allChunks.end(),
			std::make_move_iterator(docChunks.begin()),
			std::make_move_iterator(docChunks.end()));
	}
	const size_t rerankTopN =
		query.rerankTopN > query.topK ? query.rerankTopN : allChunks.size();

	std::vector<float> semanticScores;
	if (query.enableSemanticRanking) {
		semanticScores = computeSemanticScores(
			m_inference,
			query.embeddingModelPath,
			query.embeddingSettings,
			candidateQueries,
			allChunks,
			&result.usedSemanticRanking);
	}
	if (semanticScores.size() != allChunks.size()) {
		semanticScores.assign(allChunks.size(), 0.0f);
	}

	float maxKeywordScore = 0.0f;
	for (size_t i = 0; i < allChunks.size(); ++i) {
		allChunks[i].keywordScore = lexicalScoreForQueries(allChunks[i], candidateQueries);
		maxKeywordScore = std::max(maxKeywordScore, allChunks[i].keywordScore);
	}
	if (maxKeywordScore <= 0.0f) {
		maxKeywordScore = 1.0f;
	}

	for (size_t i = 0; i < allChunks.size(); ++i) {
		auto & chunk = allChunks[i];
		chunk.keywordScore /= maxKeywordScore;
		chunk.semanticScore = clampUnit((semanticScores[i] + 1.0f) * 0.5f);
		chunk.qualityScore = qualityScoreForChunk(chunk, candidateQueries);
		chunk.score =
			chunk.keywordScore * std::max(0.0f, query.keywordWeight) +
			(result.usedSemanticRanking ? chunk.semanticScore * std::max(0.0f, query.semanticWeight) : 0.0f) +
			chunk.qualityScore * std::max(0.0f, query.qualityWeight);
	}

	std::stable_sort(
		allChunks.begin(),
		allChunks.end(),
		[](const ofxGgmlRAGChunk & a, const ofxGgmlRAGChunk & b) {
			return a.score > b.score;
		});

	if (rerankTopN < allChunks.size()) {
		allChunks.resize(rerankTopN);
	}

	// Optional: apply server-side cross-encoder reranking on the top-N candidates.
	if (query.enableServerRerank && !query.rerankServerUrl.empty()) {
		const std::vector<float> serverScores = rerankViaServer(
			query.rerankServerUrl,
			query.rerankModel,
			query.query,
			allChunks);
		if (serverScores.size() == allChunks.size()) {
			float maxServerScore = 0.0f;
			for (float s : serverScores) {
				maxServerScore = std::max(maxServerScore, s);
			}
			if (maxServerScore > 0.0f) {
				for (size_t i = 0; i < allChunks.size(); ++i) {
					allChunks[i].semanticScore = clampUnit(serverScores[i] / maxServerScore);
					allChunks[i].score = allChunks[i].semanticScore;
				}
				std::stable_sort(
					allChunks.begin(),
					allChunks.end(),
					[](const ofxGgmlRAGChunk & a, const ofxGgmlRAGChunk & b) {
						return a.score > b.score;
					});
			}
		}
	}

	const size_t k = std::min(query.topK, allChunks.size());
	result.chunks.assign(allChunks.begin(), allChunks.begin() + static_cast<std::ptrdiff_t>(k));
	result.augmentedContext = buildAugmentedContext(result.chunks, query.includeSourceHeaders);
	result.cacheHit = false;
	result.success = true;
	if (query.enableRetrievalCache) {
		storeRetrievalCacheEntry(cacheKey, result);
	}
	const auto end = std::chrono::steady_clock::now();
	ofxGgmlMetrics::getInstance().recordTiming(
		"rag.retrieve",
		std::chrono::duration<double, std::milli>(end - start).count());
	return result;
}

ofxGgmlRAGResult ofxGgmlRAGPipeline::generate(
	const ofxGgmlRAGRequest & request,
	std::function<bool(const std::string &)> onChunk) const {
	const auto start = std::chrono::steady_clock::now();
	ofxGgmlRAGResult result;

	result.retrieval = retrieve(request.query);
	if (!result.retrieval.success) {
		result.error = result.retrieval.error;
		return result;
	}

	result.augmentedPrompt = buildAugmentedPrompt(
		result.retrieval.augmentedContext,
		request.query.query,
		request.promptPrefix);

	result.inference = m_inference.generate(
		request.modelPath,
		result.augmentedPrompt,
		request.inferenceSettings,
		std::move(onChunk));

	const auto end = std::chrono::steady_clock::now();
	result.elapsedMs =
		std::chrono::duration<float, std::milli>(end - start).count();

	result.success = result.inference.success;
	if (result.success) {
		result.answer = result.inference.text;
	} else {
		result.error = result.inference.error;
	}
	return result;
}

// ---------------------------------------------------------------------------
// Static helpers
// ---------------------------------------------------------------------------

std::vector<ofxGgmlRAGChunk> ofxGgmlRAGPipeline::chunkDocument(
	const ofxGgmlRAGDocument & doc,
	size_t chunkSize,
	size_t overlap) {
	std::vector<ofxGgmlRAGChunk> chunks;
	const std::string & text = doc.content;
	if (text.empty() || chunkSize == 0) {
		return chunks;
	}

	const size_t step = chunkSize > overlap ? chunkSize - overlap : 1;
	size_t start = 0;
	int idx = 0;
	while (start < text.size()) {
		size_t end = std::min(start + chunkSize, text.size());

		// Extend to the nearest word boundary if possible.
		if (end < text.size()) {
			size_t boundary = end;
			while (boundary < text.size() &&
				std::isspace(static_cast<unsigned char>(text[boundary])) == 0) {
				++boundary;
			}
			// Only extend if the word boundary is reasonably close.
			if (boundary - end <= 40) {
				end = boundary;
			}
		}

		ofxGgmlRAGChunk chunk;
		chunk.docId = doc.id;
		chunk.sourceLabel = doc.sourceLabel;
		chunk.sourceUri = doc.sourceUri;
		chunk.text = trimCopy(text.substr(start, end - start));
		chunk.chunkIndex = idx++;
		chunk.crawlDepth = doc.crawlDepth;
		chunk.sourceByteSize = doc.byteSize > 0 ? doc.byteSize : doc.content.size();
		chunk.sourceQualityHint = doc.qualityHint;
		if (!chunk.text.empty()) {
			chunks.push_back(std::move(chunk));
		}

		if (end >= text.size()) {
			break;
		}
		start += step;
	}
	return chunks;
}

float ofxGgmlRAGPipeline::scoreChunk(
	const ofxGgmlRAGChunk & chunk,
	const std::string & query) {
	if (query.empty() || chunk.text.empty()) {
		return 0.0f;
	}

	const auto queryTokens = tokenize(query);
	const auto chunkTokens = tokenize(chunk.text);

	if (queryTokens.empty() || chunkTokens.empty()) {
		return 0.0f;
	}

	// Build term frequency map for chunk.
	std::unordered_map<std::string, int> chunkTf;
	for (const auto & t : chunkTokens) {
		if (stopWords().find(t) == stopWords().end()) {
			chunkTf[t]++;
		}
	}

	// Count unique query terms that appear in the chunk (BM25-lite).
	float score = 0.0f;
	std::unordered_set<std::string> seenQueryTerms;
	for (const auto & qt : queryTokens) {
		if (stopWords().find(qt) != stopWords().end()) {
			continue;
		}
		if (seenQueryTerms.count(qt) != 0) {
			continue;
		}
		seenQueryTerms.insert(qt);

		const auto it = chunkTf.find(qt);
		if (it != chunkTf.end()) {
			// Scaled by normalized TF.
			const float tf =
				static_cast<float>(it->second) /
				static_cast<float>(chunkTokens.size());
			score += 1.0f + tf * 2.0f;
		}
	}

	// Normalize by number of distinct query terms scored.
	if (!seenQueryTerms.empty()) {
		score /= static_cast<float>(seenQueryTerms.size());
	}
	return score;
}

std::string ofxGgmlRAGPipeline::buildAugmentedContext(
	const std::vector<ofxGgmlRAGChunk> & chunks,
	bool includeSourceHeaders) {
	if (chunks.empty()) {
		return {};
	}
	std::ostringstream out;
	for (size_t i = 0; i < chunks.size(); ++i) {
		const auto & chunk = chunks[i];
		out << "[Passage " << (i + 1) << "]";
		if (includeSourceHeaders && !chunk.sourceLabel.empty()) {
			out << " " << chunk.sourceLabel;
		}
		if (includeSourceHeaders && !chunk.sourceUri.empty()) {
			out << " (" << chunk.sourceUri << ")";
		}
		out << "\n" << chunk.text << "\n\n";
	}
	return trimCopy(out.str());
}

std::string ofxGgmlRAGPipeline::buildAugmentedPrompt(
	const std::string & augmentedContext,
	const std::string & query,
	const std::string & promptPrefix) {
	std::ostringstream out;
	const std::string prefix = trimCopy(promptPrefix);
	if (!prefix.empty()) {
		out << prefix << "\n\n";
	} else {
		out << "Answer the following question using only the provided passages.\n"
			<< "If the passages do not contain enough information, say so.\n\n";
	}
	if (!augmentedContext.empty()) {
		out << "Passages:\n" << augmentedContext << "\n\n";
	}
	out << "Question: " << trimCopy(query) << "\n"
		<< "Answer:";
	return out.str();
}

std::string ofxGgmlRAGPipeline::buildRetrievalCacheKey(
	const ofxGgmlRAGQuery & query) const {
	std::ostringstream out;
	out << m_documentRevision << '\n'
		<< query.query << '\n'
		<< query.topK << '\n'
		<< query.chunkSize << '\n'
		<< query.chunkOverlap << '\n'
		<< query.includeSourceHeaders << '\n'
		<< query.enableSemanticRanking << '\n'
		<< query.allowQueryRefinement << '\n'
		<< query.enableRetrievalCache << '\n'
		<< query.keywordWeight << '\n'
		<< query.semanticWeight << '\n'
		<< query.qualityWeight << '\n'
		<< query.rerankTopN << '\n'
		<< query.maxRefinementSteps << '\n'
		<< query.embeddingModelPath << '\n'
		<< m_inference.getEmbeddingExecutable() << '\n';
	for (const auto & variant : query.queryVariants) {
		out << variant << '\n';
	}
	return out.str();
}

void ofxGgmlRAGPipeline::invalidateRetrievalCache() {
	std::lock_guard<std::mutex> lock(m_retrievalCacheMutex);
	++m_documentRevision;
	m_retrievalCache.clear();
	m_retrievalCacheLru.clear();
}

void ofxGgmlRAGPipeline::storeRetrievalCacheEntry(
	const std::string & key,
	const ofxGgmlRAGRetrievalResult & result) const {
	std::lock_guard<std::mutex> lock(m_retrievalCacheMutex);
	const auto existing = m_retrievalCache.find(key);
	if (existing != m_retrievalCache.end()) {
		existing->second.result = result;
		m_retrievalCacheLru.remove(key);
		m_retrievalCacheLru.push_front(key);
		return;
	}
	if (m_retrievalCache.size() >= RETRIEVAL_CACHE_MAX_SIZE &&
		!m_retrievalCacheLru.empty()) {
		const std::string oldestKey = m_retrievalCacheLru.back();
		m_retrievalCacheLru.pop_back();
		m_retrievalCache.erase(oldestKey);
		ofxGgmlMetrics::getInstance().recordCacheEviction("rag.retrieval");
	}
	m_retrievalCache.emplace(key, RetrievalCacheEntry{key, result});
	m_retrievalCacheLru.push_front(key);
}
