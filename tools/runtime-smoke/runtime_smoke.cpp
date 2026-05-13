#include "../../src/core/ofxGgmlRuntime.h"
#include "../../src/compute/ofxGgmlGraph.h"

#include <array>
#include <cmath>
#include <cstdlib>
#include <iostream>

namespace {

bool nearlyEqual(float a, float b) {
    return std::fabs(a - b) < 1e-5f;
}

} // namespace

int main() {
    ofxGgmlRuntime runtime;

    ofxGgmlRuntimeSettings settings;
    settings.preferredBackend = ofxGgmlBackend::CPU;
    settings.allowCpuFallback = false;

    const auto setupResult = runtime.setup(settings);
    if (!setupResult) {
        std::cerr << "CPU backend initialization failed: " << setupResult.error << std::endl;
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
        std::cerr << "Graph allocation failed: " << allocateResult.error << std::endl;
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
        std::cerr << "Output tensor readback failed: " << getResult.error << std::endl;
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
