#include "../../src/core/ofxGgmlRuntime.h"

#include <cstdlib>
#include <iostream>

int main() {
    ofxGgmlRuntime runtime;

    ofxGgmlRuntimeSettings settings;
    settings.preferredBackend = ofxGgmlBackend::CPU;
    settings.allowCpuFallback = false;

    const auto result = runtime.setup(settings);
    if (!result) {
        std::cerr << "CPU backend initialization failed: " << result.error << std::endl;
        return EXIT_FAILURE;
    }

    if (!runtime.isReady()) {
        std::cerr << "Runtime setup succeeded but runtime is not ready" << std::endl;
        return EXIT_FAILURE;
    }

    std::cout << "Runtime backend: " << runtime.getBackendName() << std::endl;

    const auto devices = runtime.getDevices();
    std::cout << "Detected devices: " << devices.size() << std::endl;
    for (const auto & device : devices) {
        std::cout << "- " << device.name << std::endl;
    }

    runtime.close();
    return EXIT_SUCCESS;
}
