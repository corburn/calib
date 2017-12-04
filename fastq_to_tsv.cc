#include <iostream>
#include <fstream>
//#include <string>
#include <stdio.h>
#include <map>

#include <cstdint> // include this header for uint64_t

using namespace std;
string bitvector_to_DNA(uint64_t k_mer, int k_mer_size){
    char dna[k_mer_size+1];
    for (int i = 0; i < k_mer_size; i++){
        char current_byte = (char) (k_mer >> ((8*(k_mer_size - i - 1)) & 0xff ));
        dna[i] = current_byte ;
    }
    dna[k_mer_size] = '\0';
    return string(dna);
}


uint64_t minimizer(string seq, int start, int length, int k_mer_size){
    if (length < k_mer_size){
        return (uint64_t) - 1;
    }
    uint64_t current_k_mer = 0;
    uint64_t min_k_mer = (uint64_t) - 1;
    uint64_t k_mer_size_mask = (uint64_t) - 1;
    k_mer_size_mask >>= (sizeof(uint64_t)-k_mer_size)*8;

    for (int i = start; i < start + k_mer_size; i++){
        current_k_mer <<= 8;
        current_k_mer |= (uint64_t) seq.at(i);
    }
    min_k_mer = min_k_mer < current_k_mer ? min_k_mer : current_k_mer;

    for (int i = start + k_mer_size; i < start + length; i++){
        current_k_mer <<= 8;
        current_k_mer &= k_mer_size_mask;
        current_k_mer |= (uint64_t) seq.at(i);
        min_k_mer = min_k_mer < current_k_mer ? min_k_mer : current_k_mer;
    }

    return min_k_mer;
}

int main(int argc, char** argv) {
    ifstream fastq1;
    ifstream fastq2;
    fastq1.open (argv[1]);
    fastq2.open (argv[2]);
    ofstream output(argv[3]);
    unsigned int barcode_length = (unsigned int) atoi(argv[4]);
    unsigned int k_mer_size = (unsigned int) atoi(argv[5]);
    unsigned int minimizers_count = (unsigned int) atoi(argv[6]);
    
    string r1, s1, q1, r2, s2, q2, trash;
    while (getline(fastq1, r1)) {
        getline(fastq1, s1);
        getline(fastq1, trash);
        getline(fastq1, q1);
        getline(fastq2, r2);
        getline(fastq2, s2);
        getline(fastq2, trash);
        getline(fastq2, q2);

        unsigned int s1_length = (unsigned int) s1.size();
        unsigned int s2_length = (unsigned int) s2.size();
        uint64_t min_kmer;

        if (s1_length < barcode_length){
            output << string (barcode_length, 'N') << "\t";
        } else {
            output << s1.substr(0, barcode_length) << "\t";
        }
        if (s2_length < barcode_length){
            output << string (barcode_length, 'N') << "\t";
        } else {
            output << s2.substr(0, barcode_length) << "\t";
        }
        s1_length -= barcode_length;
        s2_length -= barcode_length;

        int s1_seg_length = s1_length / minimizers_count;
        for (int i = 0; i < minimizers_count; i++){
            min_kmer = minimizer(s1, barcode_length + i*s1_seg_length, s1_seg_length, k_mer_size);
            output << min_kmer << "\t";
        }

        int s2_seg_length = s2_length / minimizers_count;
        for (int i = 0; i < minimizers_count; i++){
            min_kmer = minimizer(s2, barcode_length + i*s2_seg_length, s2_seg_length, k_mer_size);
            output << min_kmer << "\t";
        }
        output << "\n";
    }

    return 0;
}


