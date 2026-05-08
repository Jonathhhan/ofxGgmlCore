#pragma once

#include <string>
#include <stdexcept>
#include <utility>
#include <type_traits>
#include <variant>

/// Error codes for ofxGgml operations.
enum class ofxGgmlErrorCode {
	None = 0,

	// Initialization errors
	BackendInitFailed,
	DeviceNotFound,
	OutOfMemory,

	// Graph errors
	GraphNotBuilt,
	GraphAllocFailed,
	InvalidTensor,
	TensorShapeMismatch,

	// Computation errors
	ComputeFailed,
	SynchronizationFailed,
	AsyncOperationPending,

	// Model errors
	ModelLoadFailed,
	ModelFormatInvalid,
	ModelWeightUploadFailed,

	// Inference errors
	InferenceExecutableMissing,
	InferenceProcessFailed,
	InferenceOutputInvalid,

	// General errors
	InvalidArgument,
	NotImplemented,
	UnknownError
};

/// Detailed error information.
struct ofxGgmlError {
	ofxGgmlErrorCode code = ofxGgmlErrorCode::None;
	std::string message;

	ofxGgmlError() = default;

	explicit ofxGgmlError(ofxGgmlErrorCode c, const std::string & msg = "")
		: code(c), message(msg) {}

	/// Returns true if this represents an error (not None).
	constexpr bool hasError() const noexcept {
		return code != ofxGgmlErrorCode::None;
	}

	/// Returns a human-readable description of the error code.
	const char * codeString() const noexcept {
		switch (code) {
			case ofxGgmlErrorCode::None: return "None";
			case ofxGgmlErrorCode::BackendInitFailed: return "BackendInitFailed";
			case ofxGgmlErrorCode::DeviceNotFound: return "DeviceNotFound";
			case ofxGgmlErrorCode::OutOfMemory: return "OutOfMemory";
			case ofxGgmlErrorCode::GraphNotBuilt: return "GraphNotBuilt";
			case ofxGgmlErrorCode::GraphAllocFailed: return "GraphAllocFailed";
			case ofxGgmlErrorCode::InvalidTensor: return "InvalidTensor";
			case ofxGgmlErrorCode::TensorShapeMismatch: return "TensorShapeMismatch";
			case ofxGgmlErrorCode::ComputeFailed: return "ComputeFailed";
			case ofxGgmlErrorCode::SynchronizationFailed: return "SynchronizationFailed";
			case ofxGgmlErrorCode::AsyncOperationPending: return "AsyncOperationPending";
			case ofxGgmlErrorCode::ModelLoadFailed: return "ModelLoadFailed";
			case ofxGgmlErrorCode::ModelFormatInvalid: return "ModelFormatInvalid";
			case ofxGgmlErrorCode::ModelWeightUploadFailed: return "ModelWeightUploadFailed";
			case ofxGgmlErrorCode::InferenceExecutableMissing: return "InferenceExecutableMissing";
			case ofxGgmlErrorCode::InferenceProcessFailed: return "InferenceProcessFailed";
			case ofxGgmlErrorCode::InferenceOutputInvalid: return "InferenceOutputInvalid";
			case ofxGgmlErrorCode::InvalidArgument: return "InvalidArgument";
			case ofxGgmlErrorCode::NotImplemented: return "NotImplemented";
			case ofxGgmlErrorCode::UnknownError: return "UnknownError";
			default: return "Unknown";
		}
	}

	/// Returns a full error description combining code and message.
	std::string toString() const {
		if (!hasError()) return "No error";
		std::string result = codeString();
		if (!message.empty()) {
			result += ": " + message;
		}
		return result;
	}
};

/// Result<T> — A type that contains either a success value or an error.
///
/// This is similar to std::expected (C++23) or Rust's Result<T, E>.
/// Use it for operations that can fail with detailed error information.
///
/// Example usage:
///   Result<int> divide(int a, int b) {
///       if (b == 0) return ofxGgmlError(ofxGgmlErrorCode::InvalidArgument, "division by zero");
///       return a / b;
///   }
///
///   auto r = divide(10, 2);
///   if (r.isOk()) {
///       std::cout << "Result: " << r.value() << std::endl;
///   } else {
///       std::cout << "Error: " << r.error().toString() << std::endl;
///   }
template<typename T>
class Result {
	static_assert(!std::is_same_v<std::decay_t<T>, ofxGgmlError>,
		"Result<ofxGgmlError> is ambiguous; return Result<void> or wrap the error in another type.");
public:
	/// Construct a successful result.
	Result(T && val) : m_storage(std::in_place_index<0>, std::move(val)) {}

	Result(const T & val) : m_storage(std::in_place_index<0>, val) {}

	/// Construct an error result.
	Result(const ofxGgmlError & err) : m_storage(std::in_place_index<1>, err) {}

	Result(ofxGgmlError && err) : m_storage(std::in_place_index<1>, std::move(err)) {}

	Result(ofxGgmlErrorCode code, const std::string & msg = "")
		: m_storage(std::in_place_index<1>, code, msg) {}

	/// Factory for fluent error builders such as EnhancedError::toResult<T>().
	static Result error(const ofxGgmlError & err) {
		return Result(err);
	}

	/// Returns true if this contains a value (success).
	bool isOk() const noexcept { return std::holds_alternative<T>(m_storage); }

	/// Returns true if this contains an error.
	bool isError() const noexcept { return std::holds_alternative<ofxGgmlError>(m_storage); }

	/// Returns the success value. Throws if this contains an error.
	T & value() & {
		if (isError()) {
			throw std::runtime_error("Result::value() called on error: " + std::get<ofxGgmlError>(m_storage).toString());
		}
		return std::get<T>(m_storage);
	}

	const T & value() const & {
		if (isError()) {
			throw std::runtime_error("Result::value() called on error: " + std::get<ofxGgmlError>(m_storage).toString());
		}
		return std::get<T>(m_storage);
	}

	T && value() && {
		if (isError()) {
			throw std::runtime_error("Result::value() called on error: " + std::get<ofxGgmlError>(m_storage).toString());
		}
		return std::move(std::get<T>(m_storage));
	}

	/// Returns the error. Throws if this contains a value.
	ofxGgmlError & error() {
		if (isOk()) {
			throw std::runtime_error("Result::error() called on success value");
		}
		return std::get<ofxGgmlError>(m_storage);
	}

	const ofxGgmlError & error() const {
		if (isOk()) {
			throw std::runtime_error("Result::error() called on success value");
		}
		return std::get<ofxGgmlError>(m_storage);
	}

	/// Returns the value if present, otherwise returns the default value.
	T valueOr(const T & defaultValue) const {
		return isOk() ? std::get<T>(m_storage) : defaultValue;
	}

	T valueOr(T && defaultValue) const {
		if (isOk()) {
			return std::get<T>(m_storage);
		}
		return std::move(defaultValue);
	}

	/// Explicit bool conversion — returns true if success.
	explicit operator bool() const { return isOk(); }

private:
	std::variant<T, ofxGgmlError> m_storage;
};

/// Specialization for void (operations that don't return a value).
template<>
class Result<void> {
public:
	/// Construct a successful result.
	Result() : m_error(ofxGgmlErrorCode::None, "") {}

	/// Construct an error result.
	Result(const ofxGgmlError & err) : m_error(err) {}

	Result(ofxGgmlErrorCode code, const std::string & msg = "")
		: m_error(code, msg) {}

	static Result error(const ofxGgmlError & err) {
		return Result(err);
	}

	/// Returns true if this represents success.
	constexpr bool isOk() const noexcept { return !m_error.hasError(); }

	/// Returns true if this contains an error.
	constexpr bool isError() const noexcept { return m_error.hasError(); }

	/// Returns the error.
	const ofxGgmlError & error() const { return m_error; }

	/// Explicit bool conversion — returns true if success.
	explicit operator bool() const { return isOk(); }

private:
	ofxGgmlError m_error;
};
