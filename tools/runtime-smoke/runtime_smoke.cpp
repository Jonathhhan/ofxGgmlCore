#include "../../src/core/ofxGgmlRuntime.h"
#include "../../src/compute/ofxGgmlGraph.h"

#include <array>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>

namespace {

bool nearlyEqual(float a, float b) {
    return std::fabs(a - b) < 1e-5f;
}

ofxGgmlBackend parseBackend(const std::string & value) {
    if (value == "cpu") return ofxGgmlBackend::CPU;
    if (value == "cuda") return ofxGgmlBackend::CUDA;
    if (value == "vulkan") return ofxGgmlBackend::Vulkan;
    if (value == "metal") return ofxGgmlBackend::Metal;
    if (value == "opencl") return ofxGgmlBackend::OpenCL;
    if (value == "auto") return ofxGgmlBackend::Auto;
    std::cerr << "Unknown backend: " << value << std::endl;
    std::exit(EXIT_FAILURE);
}

bool isOptionalBackend(ofxGgmlBackend backend) {
    return backend != ofxGgmlBackend::CPU;
}

} // namespace

int main(int argc, char ** argv) {
    std::string backendName = "cpu";
    bool requireBackend = false;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--backend" && i + 1 < argc) {
            backendName = argv[++i];
        } else if (arg == "--require-backend") {
            requireBackend = true;
        } else {
            std::cerr << "Usage: runtime_smoke [--backend cpu|cuda|vulkan|metal|opencl|auto] [--require-backend]" << std::endl;
            return EXIT_FAILURE;
        }
    }

    const ofxGgmlBackend requestedBackend = parseBackend(backendName);

    ofxGgmlRuntime runtime;

    ofxGgmlRuntimeSettings settings;
    settings.preferredBackend = requestedBackend;
    settings.allowCpuFallback = false;

    const auto setupResult = runtime.setup(settings);
    if (!setupResult) {
        std::cerr << ofxGgmlGetBackendName(requestedBackend)
                  << " backend initialization failed: " << setupResult.error().message << std::endl;
        if (isOptionalBackend(requestedBackend) && !requireBackend) {
            std::cout << "Optional backend unavailable; skipping inference smoke test" << std::endl;
            return EXIT_SUCCESS;
        }
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

    ofxGgmlGraph graph;
    auto a = graph.tensor1d(ofxGgmlType::F32, 4);
    auto b = graph.tensor1d(ofxGgmlType::F32, 4);
    auto sum = graph.add(a, b);
    auto out = graph.mul(sum, b);
    graph.build(out);

    const auto allocateResult = runtime.allocate(graph);
    if (!allocateResult) {
        std::cerr << "Graph allocation failed: " << allocateResult.error().message << std::endl;
        return EXIT_FAILURE;
    }

    const std::array<float, 4> aValues { 1.0f, 2.0f, 3.0f, 4.0f };
    const std::array<float, 4> bValues { 10.0f, 20.0f, 30.0f, 40.0f };
    const std::array<float, 4> expected { 110.0f, 440.0f, 990.0f, 1760.0f };

    auto setA = runtime.setData(a, aValues.data(), sizeof(float) * aValues.size());
    auto setB = runtime.setData(b, bValues.data(), sizeof(float) * bValues.size());
    if (!setA || !setB) {
        std::cerr << "Input tensor upload failed" << std::endl;
        return EXIT_FAILURE;
    }

    const auto computeResult = runtime.compute(graph);
    if (!computeResult) {
        std::cerr << "Graph compute failed: " << computeResult.error << std::endl;
        return EXIT_FAILURE;
    }

    std::array<float, 4> actual {};
    const auto getResult = runtime.getData(out, actual.data(), sizeof(float) * actual.size());
    if (!getResult) {
        std::cerr << "Output tensor readback failed: " << getResult.error().message << std::endl;
        return EXIT_FAILURE;
    }

    for (std::size_t i = 0; i < actual.size(); ++i) {
        if (!nearlyEqual(actual[i], expected[i])) {
            std::cerr << "Unexpected inference output at " << i << ": got " << actual[i]
                      << ", expected " << expected[i] << std::endl;
            return EXIT_FAILURE;
        }
    }

    std::cout << "Lightweight inference smoke test passed" << std::endl;
    runtime.close();
    return EXIT_SUCCESS;
}
