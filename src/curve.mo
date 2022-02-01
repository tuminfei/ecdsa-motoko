import Field "field";
import Util "curve_util";

module {
  public type FpElt = { #fp : Nat; };
  public type FrElt = { #fr : Nat; };
  public type Affine = (FpElt, FpElt);
  public type Point = { #zero; #affine : Affine };

  public let params = {
    p = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f;
    r = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;
    a = #fp(0);
    b = #fp(7);
    g = (#fp(0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798), #fp(0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8));
	  // rHalf_ = (r_ + 1) / 2;
	  rHalf = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1;
  };	

  let G_ = #affine(params.g);

  let p_ = params.p;
  let r_ = params.r;
  let a_ = params.a;
  let b_ = params.b;
  // pSqrRoot_ = (p_ + 1) / 4;
  let pSqrRoot_ : Nat = 0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffbfffff0c;

  public let Fp = {
    fromNat = func (n : Nat) : FpElt = #fp(n % p_);
    toNat = func (#fp(x) : FpElt) : Nat = x;
    add = func(#fp(x) : FpElt, #fp(y) : FpElt) : FpElt = #fp(Field.add_(x, y, p_));
    mul = func(#fp(x) : FpElt, #fp(y) : FpElt) : FpElt = #fp(Field.mul_(x, y, p_));
    sub = func(#fp(x) : FpElt, #fp(y) : FpElt) : FpElt = #fp(Field.sub_(x, y, p_));
    div = func(#fp(x) : FpElt, #fp(y) : FpElt) : FpElt = #fp(Field.div_(x, y, p_));
    pow = func(#fp(x) : FpElt, n : Nat) : FpElt = #fp(Field.pow_(x, n, p_));
    neg = func(#fp(x) : FpElt) : FpElt = #fp(Field.neg_(x, p_));
    inv = func(#fp(x) : FpElt) : FpElt = #fp(Field.inv_(x, p_));
    sqr = func(#fp(x) : FpElt) : FpElt = #fp(Field.sqr_(x, p_));
  };
  public let Fr = {
    fromNat = func (n : Nat) : FrElt = #fr(n % r_);
    toNat = func (#fr(x) : FrElt) : Nat = x;
    add = func(#fr(x) : FrElt, #fr(y) : FrElt) : FrElt = #fr(Field.add_(x, y, r_));
    mul = func(#fr(x) : FrElt, #fr(y) : FrElt) : FrElt = #fr(Field.mul_(x, y, r_));
    sub = func(#fr(x) : FrElt, #fr(y) : FrElt) : FrElt = #fr(Field.sub_(x, y, r_));
    div = func(#fr(x) : FrElt, #fr(y) : FrElt) : FrElt = #fr(Field.div_(x, y, r_));
    pow = func(#fr(x) : FrElt, n : Nat) : FrElt = #fr(Field.pow_(x, n, r_));
    neg = func(#fr(x) : FrElt) : FrElt = #fr(Field.neg_(x, r_));
    inv = func(#fr(x) : FrElt) : FrElt = #fr(Field.inv_(x, r_));
    sqr = func(#fr(x) : FrElt) : FrElt = #fr(Field.sqr_(x, r_));
  };

  // public only for testing
  public func fpSqrRoot(x : FpElt) : ?FpElt {
    let sq = Fp.pow(x, pSqrRoot_);
    if (Fp.sqr(sq) == x) ?sq else null
  };

  // return x^3 + ax + b
  func getYsqrFromX(x : FpElt) : FpElt =
    Fp.add(Fp.mul(Fp.add(Fp.sqr(x), a_), x), b_);

  /// Get y corresponding to x such that y^2 = x^ + ax + b.
  /// Return even y if `even` is true.
  public func getYfromX(x : FpElt, even : Bool) : ?FpElt {
    let y2 = getYsqrFromX(x);
    switch (fpSqrRoot(y2)) {
      case (null) null;
      case (?y) if (even == ((Fp.toNat(y) % 2) == 0)) ?y else ?Fp.neg(y);
    }
  };

  // point functions
  public func isValid((x,y) : Affine) : Bool = Fp.sqr(y) == getYsqrFromX(x);
  public func isZero(a : Point) : Bool = a == #zero;
  public func isNegOf(a : Point, b : Point) : Bool = a == neg(b);
  public func neg(p : Point) : Point = switch (p) {
    case (#zero) #zero;
    case (#affine(c)) #affine(c.0, Fp.neg(c.1));
  };
  func dbl_affine((x,y) : Affine) : Affine {
    let xx = Fp.mul(x,x);
    let xx3 = Fp.add(Fp.add(xx, xx), xx);
    let nume = Fp.add(xx3, a_);
    let deno = Fp.add(y,y);
    let L = Fp.div(nume, deno);
    let x3 = Fp.sub(Fp.mul(L, L), Fp.add(x,x));
    let y3 = Fp.sub(Fp.mul(L, Fp.sub(x, x3)), y);
    (x3, y3)
  };
  public func dbl(a : Point) : Point = switch (a) {
    case (#zero) #zero;
    case (#affine(c)) #affine(dbl_affine(c));
  };
  public func add(a : Point, b : Point) : Point = switch (a, b) {
    case (#zero, b) return b;
    case (a, #zero) return a;
    case (#affine(ax,ay), #affine(bx,by)) {
      if (ax == bx) {
        // P + (-P) or P + P 
        return if (ay == Fp.neg(by)) #zero else dbl(a);
      } else {
        let L = Fp.div(Fp.sub(ay, by), Fp.sub(ax, bx));
        let x3 = Fp.sub(Fp.mul(L, L), Fp.add(ax, bx));
        let y3 = Fp.sub(Fp.mul(L, Fp.sub(ax, x3)), ay);
        return #affine(x3, y3);
      };
    };
  };
  public func mul(a : Point, #fr(x) : FrElt) : Point {
    let bs = Util.toReverseBin(x);
    let n = bs.size();
    var ret : Point = #zero;
    var i = 0;
    while (i < n) {
      let b = bs[n - 1 - i];
      ret := dbl(ret);
      if (b) ret := add(ret, a);
      i += 1;
    };
    ret
  };
  public func mul_base(e : FrElt) : Point = mul(G_, e);

  public type Jacobi = (FpElt, FpElt, FpElt);
  public let zeroJ = (#fp(0), #fp(0), #fp(0));
  public func isZeroJacobi((_, _, z) : Jacobi) : Bool = z == #fp(0);
  public func toJacobi(a : Point) : Jacobi = switch (a) {
    case (#zero) zeroJ;
    case (#affine(x, y)) (x, y, #fp(1));
  };
  public func fromJacobi((x, y, z) : Jacobi) : Point {
    if (z == #fp(0)) return #zero;
    let rz = Fp.inv(z);
    let rz2 = Fp.sqr(rz);
    #affine((Fp.mul(x, rz2), Fp.mul(Fp.mul(y, rz2), rz)))
  };
  // y^2 == x(x^2 + a z^4) + b z^6
  public func isValidJacobi((x, y, z) : Jacobi) : Bool {
    let x2 = Fp.sqr(x);
    let y2 = Fp.sqr(y);
    let z2 = Fp.sqr(z);
    var z4 = Fp.sqr(z2);
    var t = Fp.mul(z4, a_);
    t := Fp.add(t, x2);
    t := Fp.mul(t, x);
    z4 := Fp.mul(z4, z2);
    z4 := Fp.mul(z4, b_);
    t := Fp.add(t, z4);
    y2 == t
  };
  public func negJacobi((x, y, z) : Jacobi) : Jacobi = (x, Fp.neg(y), z);
  public func dblJacobi((x, y, z) : Jacobi) : Jacobi {
    if (z == #fp(0)) return zeroJ;
    var x2 = Fp.sqr(x);
    var y2 = Fp.sqr(y);
    var xy = Fp.mul(x, y2);
    xy := Fp.add(xy, xy);
    y2 := Fp.sqr(y2);
    xy := Fp.add(xy, xy);
    assert(a_ == #fp(0));
    var t = Fp.add(x2, x2);
    x2 := Fp.add(x2, t);
    var rx = Fp.sqr(x2);
    rx := Fp.sub(rx, xy);
    rx := Fp.sub(rx, xy);
    var rz : FpElt = if (z == #fp(1)) y else Fp.mul(y, z);
    rz := Fp.add(rz, rz);
    var ry = Fp.sub(xy, x);
    ry := Fp.mul(ry, x2);
    y2 := Fp.add(y2, y2);
    y2 := Fp.add(y2, y2);
    y2 := Fp.add(y2, y2);
    ry := Fp.sub(ry, y2);
    (rx, ry, rz)
  };
  public func addJacobi((px, py, pz) : Jacobi, (qx,qy, qz) : Jacobi) : Jacobi {
    if (pz == #fp(0)) return (qx, qy, qz);
    if (qz == #fp(0)) return (px, py, pz);
    let isPzOne = pz == #fp(1);
    let isQzOne = qz == #fp(1);
    var r = #fp(1);
    if (isPzOne) r := Fp.sqr(pz);
    var U1 = #fp(0);
    var S1 = #fp(0);
    var H = #fp(0);
    if (isQzOne) {
      U1 := px;
      if (isPzOne) {
        H := qx;
      } else {
        H := Fp.mul(qx, r);
      };
      H := Fp.sub(H, U1);
      S1 := py;
    } else {
      S1 := Fp.sqr(qz);
      U1 := Fp.mul(px, S1);
      if (isPzOne) {
        H := qx;
      } else {
        H := Fp.mul(qx, r);
      };
      H := Fp.sub(H, U1);
      S1 := Fp.mul(S1, qz);
      S1 := Fp.mul(S1, py);
    };
    if (isPzOne) {
      r := qy;
    } else {
      r := Fp.mul(r, pz);
      r := Fp.mul(r, qy);
    };
    r := Fp.sub(r, S1);
    if (H == #fp(1)) {
      if (r == #fp(0)) {
        return dblJacobi((px, py, pz));
      } else {
        return zeroJ;
      };
    };
    var rx = #fp(0);
    var ry = #fp(0);
    var rz = #fp(0);
    if (isPzOne) {
      if (isQzOne) {
        rz := H;
      } else {
        rz := Fp.mul(H, qz);
      };
    } else {
      if (isQzOne) {
        rz := Fp.mul(pz, H);
      } else {
        rz := Fp.mul(pz, qz);
        rz := Fp.mul(rz, H);
      };
    };
    var H3 = Fp.sqr(H);
    ry := Fp.sqr(r);
    U1 := Fp.mul(U1, H3);
    H3 := Fp.mul(H3, H);
    ry := Fp.sub(ry, U1);
    ry := Fp.sub(ry, U1);
    rx := Fp.sub(ry, H3);
    U1 := Fp.sub(U1, rx);
    U1 := Fp.mul(U1, r);
    H3 := Fp.mul(H3, S1);
    ry := Fp.sub(U1, H3);
    (rx, ry, rz)
  };
}