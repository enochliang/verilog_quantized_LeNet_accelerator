#include <iostream>
#include <fstream>
#include <iomanip>
#include <random>
#include <string>

/**
 * LeNet Random Pattern Generator
 * * This program generates quantized weights and image data for RTL simulation.
 * Format: 32-bit hexadecimal strings (8 hex digits per line).
 */

class PatternGenerator {
private:
    std::mt19937 rng;

    // Helper to generate a random 32-bit unsigned integer
    uint32_t getRandom32() {
        std::uniform_int_distribution<uint32_t> dist(0, 0xFFFFFFFF);
        return dist(rng);
    }

    // Helper to generate a random 8-bit unsigned integer (a single parameter/pixel)
    uint8_t getRandom8() {
        std::uniform_int_distribution<uint16_t> dist(0, 0xFF);
        return static_cast<uint8_t>(dist(rng));
    }

public:
    PatternGenerator() {
        std::random_device rd;
        rng.seed(rd());
    }

    void generateImage(const std::string& filename) {
        std::ofstream outFile(filename);
        if (!outFile.is_open()) {
            std::cerr << "Error: Could not open " << filename << " for writing." << std::endl;
            return;
        }

        // image.csv: 256 lines, each line is 32 bits (4 pixels, 8 bits each)
        for (int i = 0; i < 256; ++i) {
            uint32_t data = getRandom32();
            outFile << std::hex << std::setw(8) << std::setfill('0') << std::uppercase << data << "\n";
        }

        outFile.close();
        std::cout << "Successfully generated " << filename << std::endl;
    }

    void generateWeights(const std::string& filename) {
        std::ofstream outFile(filename);
        if (!outFile.is_open()) {
            std::cerr << "Error: Could not open " << filename << " for writing." << std::endl;
            return;
        }

        /**
         * Part 1: Lines 0 to 1019
         * Constraint: 5 parameters per 2 lines.
         * Line 2n:   [W3][W2][W1][W0] (32 bits)
         * Line 2n+1: [00][00][00][W4] (8 bits data, 24 bits zero)
         */
        for (int i = 0; i < 1020; i += 2) {
            // Line 2n: 4 random weights
            uint32_t lineEven = getRandom32();
            outFile << std::hex << std::setw(8) << std::setfill('0') << std::uppercase << lineEven << "\n";

            // Line 2n+1: 1 random weight at the lowest 8 bits, others are 0
            uint32_t weight4 = getRandom8();
            uint32_t lineOdd = weight4 & 0x000000FF; 
            outFile << std::hex << std::setw(8) << std::setfill('0') << std::uppercase << lineOdd << "\n";
        }

        /**
         * Part 2: Lines 1020 to 15759
         * Fully random 32-bit values.
         */
        for (int i = 1020; i < 15760; ++i) {
            uint32_t data = getRandom32();
            outFile << std::hex << std::setw(8) << std::setfill('0') << std::uppercase << data << "\n";
        }

        outFile.close();
        std::cout << "Successfully generated " << filename << std::endl;
    }
};

int main() {
    PatternGenerator generator;

    std::cout << "Starting Pattern Generation..." << std::endl;
    
    generator.generateImage("image.csv");
    //generator.generateWeights("weights.csv");

    std::cout << "Generation Complete." << std::endl;

    return 0;
}
