pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

// TODO reputation to track credit history


contract Reputation {

    enum ratings{ Negative, Neutral, Positive }

    struct ReputationStruct {
        address from;
        string details;
        ratings rating;
    }

    struct sourceStruct {
        mapping (uint => ReputationStruct) reps;
    }

    struct addressStruct {
        mapping (address => sourceStruct) sources;
    }

    mapping (address => addressStruct) private history;

    //
}