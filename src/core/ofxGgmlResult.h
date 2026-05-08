#pragma once

#include <stdexcept>
#include <string>
#include <type_traits>
#include <utility>
#include <variant>

struct ofxGgmlError {
	std::string message;
	int code = 0;
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
