#include "hv_struct.hpp"
#include <ctime>

// Default constructor: Initializes all data elements to zero
HV::HV() {
    for (int i = 0; i < HV_CHUNKS; ++i) {
        chunk[i] = 0;
    }
}

// Copy constructor
HV::HV(const HV& other) {
    for (int i = 0; i < HV_CHUNKS; ++i) {
        chunk[i] = other.chunk[i];
    }
}

// Define the assignment operator
HV& HV::operator=(const HV& other) {
    if (this != &other) {
        for (int i = 0; i < HV_CHUNKS; ++i) {
            chunk[i] = other.chunk[i];
        }
    }
    return *this;
}

// Define the equality operator
bool HV::operator==(const HV& other) const {
    for (int i = 0; i < HV_CHUNKS; ++i) {
        if (chunk[i] != other.chunk[i]) {
            return false;
        }
    }
    return true;
}

// Define the randomize function
void HV::randomize() {
    for (int i = 0; i < HV_CHUNKS; ++i) {
        int random_number = rand();
        chunk[i] = random_number;
    }
}

// Print Operator, bit by bit
void HV::print() {
    printf("[");
    for (int i = HV_CHUNKS -1; i >= 0; --i) {
        for (int j = 31; j >= 0; --j) {
            printf("%d", (chunk[i] >> j) & 1);
        }
    }
    printf("]\n");
}


// Print Operator, bit by bit (element by element of COUNTER_BITS)
void BundledHV::print() {
    int element_mask = (1 << COUNTER_BITS) - 1;

    printf("[");
    // We have HV_CHUNKS * COUNTER_BITS elements
    for (int i = HV_CHUNKS * COUNTER_BITS -1 ; i >= 0 ; --i) {
        // Extract each COUNTER_BITS-sized element within bundled_chunk[i]
        // For a 32-bit integer, we have 32/COUNTER_BITS elements.
        for (int j = 32 - COUNTER_BITS; j >= 0; j -= COUNTER_BITS) {
            int element_value = (bundled_chunk[i] >> j) & element_mask;
            // Print element_value in decimal
            printf("%d", element_value);
        }
    }
    printf("]\n");
}

// Default constructor: Initializes all data elements to zero
BundledHV::BundledHV() {
    for (int i = 0; i < HV_CHUNKS * COUNTER_BITS; ++i) {
        bundled_chunk[i] = 0;
    }
}

// Copy constructor
BundledHV::BundledHV(const BundledHV& other) {
    for (int i = 0; i < HV_CHUNKS * COUNTER_BITS; ++i) {
        bundled_chunk[i] = other.bundled_chunk[i];
    }
}

// Define the assignment operator
BundledHV& BundledHV::operator=(const BundledHV& other) {
    if (this != &other) {
        for (int i = 0; i < HV_CHUNKS * COUNTER_BITS; ++i) {
            bundled_chunk[i] = other.bundled_chunk[i];
        }
    }
    return *this;
}

// Define the assignment operator
BundledHV& BundledHV::operator=(const HV& other) {
    int bundled_index = 0;
    int bit_position = 32 - COUNTER_BITS;
    int element_mask = (1 << COUNTER_BITS) - 1;
    for (int i = 0; i < HV_CHUNKS; ++i) {  // Iterate over each 32-bit chunk in HV
        for (int bit = 31; bit >= 0; --bit) {  // Iterate over each bit in the 32-bit chunk
            if ((other.chunk[i] >> bit) & 1) {
                bundled_chunk[bundled_index] |= (0x1 << bit_position);
            } else {
                bundled_chunk[bundled_index] &= ~(element_mask);
            }
            bit_position -= COUNTER_BITS;
            if (bit_position < 0) {
                bit_position = 32 - COUNTER_BITS;
                bundled_index++;
            }
        }
    }
    
    return *this;
}

//Define the equality operator
bool BundledHV::operator==(const BundledHV& other) const {
    for (int i = 0; i < HV_CHUNKS * COUNTER_BITS; ++i) {
        if (bundled_chunk[i] != other.bundled_chunk[i]) {
            return false;
        }
    }   
    return true;
}

// Define the randomize function
void BundledHV::randomize() {
    for (int i = 0; i < HV_CHUNKS * COUNTER_BITS; ++i) {
        int random_number = rand();
        bundled_chunk[i] = random_number;
    }
}

