//
// Created by borabi on 19/12/17.
//

#include "parse_flags.h"
#include "string"
#include <iostream>
using namespace std;


// Parameter definitions
string input_prefix;
string output_prefix;
int barcode_length;
int minimizer_count;
int error_tolerance;
int minimizer_threshold;

int main(int argc, char *argv[]){
    parse_flags(argc, argv);
    cout << barcode_length << "\n";
    cout << minimizer_count << "\n";
    cout << error_tolerance << "\n";
    cout << minimizer_threshold << "\n";
    cout << input_prefix << "\n";
    cout << output_prefix << "\n";

}