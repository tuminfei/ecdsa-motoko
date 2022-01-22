import M "../src";
import Nat "mo:base/Nat";

func benchGen(n : Nat) {
  let sec = 0x83ecb3984a4f9ff03e84d5f9c0d7f888a81833643047acc58eb6431e01d9bac8;
  var i : Nat = 0;
  while (i < n) {
    let pub = M.getPublicKey(sec);
    i := i + 1;
  };
};

// 1.7 sec @Xeon Platinum 8280 CPU 2.70GHz 2021/01/22
let loopN = 10;
benchGen(loopN);