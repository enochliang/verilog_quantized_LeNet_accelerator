#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <iomanip>
#include <sstream>
#include <algorithm>
#include <cstdint>

using namespace std;

// --- Utility Functions ---

/**
 * Converts a 32-bit unsigned hex string to a uint32_t
 */
uint32_t hexToUint(const string& hexStr) {
    uint32_t val;
    stringstream ss;
    ss << hex << hexStr;
    ss >> val;
    return val;
}

/**
 * Requantization logic: Partial Sum -> ReLU -> Requantize -> Clamp
 * Formula: Clamp(( (ReLU(PS)) * SF ) >> 16)
 */
int8_t requantize(int32_t partial_sum, int32_t scale) {
    // ReLU
    int32_t activated = (partial_sum < 0) ? 0 : partial_sum;
    // Requantize (Assumed product fits in 32-bit signed integer per instructions)
    int32_t intermediate = (activated * scale) >> 16;
    // Clamp to 8-bit signed integer (-128 to 127)
    if (intermediate > 127) intermediate = 127;
    if (intermediate < -128) intermediate = -128;
    return (int8_t)intermediate;
}

/**
 * Formats data into 32-bit hex words (8 hex digits)
 */
string toHexWord(uint32_t value) {
    stringstream ss;
    ss << setfill('0') << setw(8) << hex << value;
    return ss.str();
}

// --- LeNet Golden Model Class ---

class LeNetGoldenModel {
public:
    vector<int8_t> image;
    vector<int32_t> scales;
    
    // Weights
    vector<int8_t> conv1_w, conv2_w, fc1_w, fc2_w, fc3_w;
    vector<int32_t> fc3_b;

    // Activations
    vector<int8_t> conv1_out, conv2_out, fc1_out, fc2_out;
    vector<int32_t> fc3_out; // 32-bit output for the final layer

    void loadScales(string filename) {
        ifstream file(filename);
        int32_t s;
        while (file >> s) scales.push_back(s);
    }

    void loadImage(string filename) {
        ifstream file(filename);
        string line;
        while (file >> line) {
            uint32_t word = hexToUint(line);
            // Layout: [P3][P2][P1][P0]. Rightmost is first.
            for (int i = 0; i < 4; ++i) {
                image.push_back((int8_t)((word >> (i * 8)) & 0xFF));
            }
        }
    }

    void loadWeights(string filename) {
        ifstream file(filename);
        string line;
        vector<uint32_t> raw_mem;
        while (file >> line) raw_mem.push_back(hexToUint(line));

        int ptr = 0;
        // CONV1: 150 weights (6*5*5). 5 weights per 2 lines.
        for (int i = 0; i < 30; ++i) {
            uint32_t w_low = raw_mem[ptr++];
            uint32_t w_high = raw_mem[ptr++];
            for(int j=0; j<4; ++j) conv1_w.push_back((int8_t)((w_low >> (j*8)) & 0xFF));
            conv1_w.push_back((int8_t)(w_high & 0xFF));
        }

        // CONV2: 2400 weights (16*6*5*5). 5 weights per 2 lines.
        for (int i = 0; i < 480; ++i) {
            uint32_t w_low = raw_mem[ptr++];
            uint32_t w_high = raw_mem[ptr++];
            for(int j=0; j<4; ++j) conv2_w.push_back((int8_t)((w_low >> (j*8)) & 0xFF));
            conv2_w.push_back((int8_t)(w_high & 0xFF));
        }

        // FC1: 48000 weights. 4 per line.
        for (int i = 0; i < 12000; ++i) {
            uint32_t w = raw_mem[ptr++];
            for(int j=0; j<4; ++j) fc1_w.push_back((int8_t)((w >> (j*8)) & 0xFF));
        }

        // FC2: 10080 weights. 4 per line.
        for (int i = 0; i < 2520; ++i) {
            uint32_t w = raw_mem[ptr++];
            for(int j=0; j<4; ++j) fc2_w.push_back((int8_t)((w >> (j*8)) & 0xFF));
        }

        // FC3: 840 weights. 4 per line.
        for (int i = 0; i < 210; ++i) {
            uint32_t w = raw_mem[ptr++];
            for(int j=0; j<4; ++j) fc3_w.push_back((int8_t)((w >> (j*8)) & 0xFF));
        }

        // FC3 Bias: 10 parameters (32-bit).
        for (int i = 0; i < 10; ++i) {
            fc3_b.push_back((int32_t)raw_mem[ptr++]);
        }
    }

    void runInference() {
        // --- CONV1 ---
        // Input 32x32x1 -> Output 28x28x6 -> MaxPool 14x14x6
        vector<int8_t> p1_out(1344);
        for (int oc = 0; oc < 6; ++oc) {
            vector<int32_t> conv_res(28 * 28, 0);
            for (int oh = 0; oh < 28; ++oh) {
                for (int ow = 0; ow < 28; ++ow) {
                    int32_t sum = 0;
                    for (int kh = 0; kh < 5; ++kh) {
                        for (int kw = 0; kw < 5; ++kw) {
                            sum += (int32_t)image[(oh + kh) * 32 + (ow + kw)] * conv1_w[oc * 25 + kh * 5 + kw];
                        }
                    }
                    conv_res[oh * 28 + ow] = sum;
                }
            }
            // Max Pooling 2x2 + Requant
            for (int ph = 0; ph < 14; ++ph) {
                for (int pw = 0; pw < 14; ++pw) {
                    int32_t m = -2147483648;
                    for (int i = 0; i < 2; ++i) {
                        for (int j = 0; j < 2; ++j) {
                            m = max(m, conv_res[(ph * 2 + i) * 28 + (pw * 2 + j)]);
                        }
                    }
                    p1_out[oc * 224 + ph * 16 + pw] = requantize(m, scales[0]);
                }
                p1_out[oc * 224 + ph * 16 + 14] = 0;
                p1_out[oc * 224 + ph * 16 + 15] = 0;
            }
        }
        conv1_out = p1_out;

        // --- CONV2 ---
        // Input 14x14x6 -> Output 10x10x16 -> MaxPool 5x5x16
        vector<int8_t> p2_out(400);
        for (int oc = 0; oc < 16; ++oc) {
            vector<int32_t> conv_res(100, 0);
            for (int oh = 0; oh < 10; ++oh) {
                for (int ow = 0; ow < 10; ++ow) {
                    int32_t sum = 0;
                    for (int ic = 0; ic < 6; ++ic) {
                        for (int kh = 0; kh < 5; ++kh) {
                            for (int kw = 0; kw < 5; ++kw) {
                                //sum += (int32_t)p1_out[ic * 196 + (oh + kh) * 14 + (ow + kw)] * conv2_w[oc * 150 + ic * 25 + kh * 5 + kw];
				sum += (int32_t)p1_out[ic * 224 + (oh + kh) * 16 + (ow + kw)] * conv2_w[oc * 150 + ic * 25 + kh * 5 + kw];
                            }
                        }
                    }
                    conv_res[oh * 10 + ow] = sum;
                }
            }
            // Max Pooling 2x2 + Requant
            for (int ph = 0; ph < 5; ++ph) {
                for (int pw = 0; pw < 5; ++pw) {
                    int32_t m = -2147483648;
                    for (int i = 0; i < 2; ++i) {
                        for (int j = 0; j < 2; ++j) {
                            m = max(m, conv_res[(ph * 2 + i) * 10 + (pw * 2 + j)]);
                        }
                    }
                    p2_out[oc * 25 + ph * 5 + pw] = requantize(m, scales[1]);
                }
            }
        }
        conv2_out = p2_out;

        // --- FC1 ---
        for (int i = 0; i < 120; ++i) {
            int32_t sum = 0;
            for (int j = 0; j < 400; ++j) sum += (int32_t)conv2_out[j] * fc1_w[i * 400 + j];
            fc1_out.push_back(requantize(sum, scales[2]));
        }

        // --- FC2 ---
        for (int i = 0; i < 84; ++i) {
            int32_t sum = 0;
            for (int j = 0; j < 120; ++j) sum += (int32_t)fc1_out[j] * fc2_w[i * 120 + j];
            fc2_out.push_back(requantize(sum, scales[3]));
        }

        // --- FC3 ---
        // Instruction note: FC3 output is 32-bit with bias. Requant not applied to final output storage.
        for (int i = 0; i < 10; ++i) {
            int32_t sum = 0;
            for (int j = 0; j < 84; ++j) sum += (int32_t)fc2_out[j] * fc3_w[i * 84 + j];
            fc3_out.push_back(sum + fc3_b[i]);
        }
    }

    void writeGolden(string filename) {
        ofstream file(filename);
        
        // Helper to pack 8-bit vectors into 32-bit hex lines
        auto pack8To32 = [&](const vector<int8_t>& data) {
            for (size_t i = 0; i < data.size(); i += 4) {
                uint32_t word = 0;
                for (int j = 0; j < 4; ++j) {
                    if (i + j < data.size()) {
                        uint32_t byte = (uint8_t)data[i + j];
                        word |= (byte << (j * 8));
                    }
                }
                file << toHexWord(word) << endl;
            }
        };

        pack8To32(image);     // 0~255
        pack8To32(conv1_out); // 256~549 (1176 bytes)
        pack8To32(conv2_out); // 592~ (400 bytes)
        pack8To32(fc1_out);   // 692~ (120 bytes)
        pack8To32(fc2_out);   // 722~ (84 bytes)
        
        // FC3 output: 32-bit each
        for (auto val : fc3_out) {
            file << toHexWord((uint32_t)val) << endl;
        }
    }
};

int main() {
    LeNetGoldenModel model;
    
    model.loadScales("scale.csv");
    model.loadImage("image.csv");
    model.loadWeights("weights.csv");
    
    model.runInference();
    
    model.writeGolden("golden.csv");
    
    return 0;
}
