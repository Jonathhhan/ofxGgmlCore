#pragma once

#include <stdexcept>
#include <string>
#include <type_traits>
#include <utility>
#include <variant>

enum class ofxGgmlDiagnosticCode : int {
	Ok = 0,
	Unknown = 1,
	InvalidArgument = 100,
	MissingFile = 101,
	MissingDependency = 102,
	BackendUnavailable = 200,
	RuntimeSetupFailed = 201,
	ModelPathEmpty = 300,
	ModelMetadataReadFailed = 301
};

inline int ofxGgmlToDiagnosticCode(ofxGgmlDiagnosticCode code) {
	return static_cast<int>(code);
}

inline ofxGgmlDiagnosticCode ofxGgmlGetDiagnosticCode(int code) {
	switch (static_cast<ofxGgmlDiagnosticCode>(code)) {
	case ofxGgmlDiagnosticCode::Ok:
	case ofxGgmlDiagnosticCode::Unknown:
	case ofxGgmlDiagnosticCode::InvalidArgument:
	case ofxGgmlDiagnosticCode::MissingFile:
	case ofxGgmlDiagnosticCode::MissingDependency:
	case ofxGgmlDiagnosticCode::BackendUnavailable:
	case ofxGgmlDiagnosticCode::RuntimeSetupFailed:
	case ofxGgmlDiagnosticCode::ModelPathEmpty:
	case ofxGgmlDiagnosticCode::ModelMetadataReadFailed:
		return static_cast<ofxGgmlDiagnosticCode>(code);
	default:
		return ofxGgmlDiagnosticCode::Unknown;
	}
}

inline const char * ofxGgmlGetDiagnosticCodeName(ofxGgmlDiagnosticCode code) {
	switch (code) {
	case ofxGgmlDiagnosticCode::Ok:
		return "ok";
	case ofxGgmlDiagnosticCode::InvalidArgument:
		return "invalid-argument";
	case ofxGgmlDiagnosticCode::MissingFile:
		return "missing-file";
	case ofxGgmlDiagnosticCode::MissingDependency:
		return "missing-dependency";
	case ofxGgmlDiagnosticCode::BackendUnavailable:
		return "backend-unavailable";
	case ofxGgmlDiagnosticCode::RuntimeSetupFailed:
		return "runtime-setup-failed";
	case ofxGgmlDiagnosticCode::ModelPathEmpty:
		return "model-path-empty";
	case ofxGgmlDiagnosticCode::ModelMetadataReadFailed:
		return "model-metadata-read-failed";
	case ofxGgmlDiagnosticCode::Unknown:
	default:
		return "unknown";
	}
}

struct ofxGgmlError {
	std::string message;
	int code = 0;

	ofxGgmlDiagnosticCode getDiagnosticCode() const {
		return ofxGgmlGetDiagnosticCode(code);
	}

	const char * getCodeName() const {
		return ofxGgmlGetDiagnosticCodeName(getDiagnosticCode());
	}
};

template<typename T>
class ofxGgmlResult {
	static_assert(!std::is_same_v<T, ofxGgmlError>,
		"ofxGgmlResult<ofxGgmlError> is ambiguous.");

public:
	ofxGgmlResult(const T & value) : storage(value) {}
	ofxGgmlResult(T && value) : storage(std::move(value)) {}
	ofxGgmlResult(const ofxGgmlError & error) : storage(error) {}
	ofxGgmlResult(ofxGgmlError && error) : storage(std::move(error)) {}

	static ofxGgmlResult success(T value) {
		return ofxGgmlResult(std::move(value));
	}

	static ofxGgmlResult failure(std::string message, int code = 0) {
		return ofxGgmlResult(ofxGgmlError { std::move(message), code });
	}

	static ofxGgmlResult failure(std::string message, ofxGgmlDiagnosticCode code) {
		return failure(std::move(message), ofxGgmlToDiagnosticCode(code));
	}

	explicit operator bool() const {
		return isOk();
	}

	bool isOk() const {
		return std::holds_alternative<T>(storage);
	}

	bool isError() const {
		return !isOk();
	}

	T & value() & {
		if (isError()) throw std::runtime_error(error().message);
		return std::get<T>(storage);
	}

	const T & value() const & {
		if (isError()) throw std::runtime_error(error().message);
		return std::get<T>(storage);
	}

	T && value() && {
		if (isError()) throw std::runtime_error(error().message);
		return std::move(std::get<T>(storage));
	}

	const ofxGgmlError & error() const {
		if (isOk()) {
			static const ofxGgmlError empty;
			return empty;
		}
		return std::get<ofxGgmlError>(storage);
	}

private:
	std::variant<T, ofxGgmlError> storage;
};

template<>
class ofxGgmlResult<void> {
public:
	ofxGgmlResult() = default;
	ofxGgmlResult(ofxGgmlError error)
		: ok(false)
		, err(std::move(error)) {}

	static ofxGgmlResult success() {
		return {};
	}

	static ofxGgmlResult failure(std::string message, int code = 0) {
		return ofxGgmlResult(ofxGgmlError { std::move(message), code });
	}

	static ofxGgmlResult failure(std::string message, ofxGgmlDiagnosticCode code) {
		return failure(std::move(message), ofxGgmlToDiagnosticCode(code));
	}

	explicit operator bool() const {
		return ok;
	}

	bool isOk() const {
		return ok;
	}

	bool isError() const {
		return !ok;
	}

	const ofxGgmlError & error() const {
		return err;
	}

private:
	bool ok = true;
	ofxGgmlError err;
};
