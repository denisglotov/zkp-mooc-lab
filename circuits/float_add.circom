pragma circom 2.0.0;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////// Templates from the circomlib ////////////////////////////////
////////////////// Copy-pasted here for easy reference //////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

/*
 * Outputs `a` AND `b`
 */
template AND() {
    signal input a;
    signal input b;
    signal output out;

    out <== a*b;
}

/*
 * Outputs `a` OR `b`
 */
template OR() {
    signal input a;
    signal input b;
    signal output out;

    out <== a + b - a*b;
}

/*
 * `out` = `cond` ? `L` : `R`
 */
template IfThenElse() {
    signal input cond;
    signal input L;
    signal input R;
    signal output out;

    out <== cond * (L - R) + R;
}

/*
 * (`outL`, `outR`) = `sel` ? (`R`, `L`) : (`L`, `R`)
 */
template Switcher() {
    signal input sel;
    signal input L;
    signal input R;
    signal output outL;
    signal output outR;

    signal aux;

    aux <== (R-L)*sel;
    outL <==  aux + L;
    outR <== -aux + R;
}

/*
 * Decomposes `in` into `b` bits, given by `bits`.
 * Least significant bit in `bits[0]`.
 * Enforces that `in` is at most `b` bits long.
 */
template Num2Bits(b) {
    signal input in;
    signal output bits[b];

    for (var i = 0; i < b; i++) {
        bits[i] <-- (in >> i) & 1;
        bits[i] * (1 - bits[i]) === 0;
    }
    var sum_of_bits = 0;
    for (var i = 0; i < b; i++) {
        sum_of_bits += (2 ** i) * bits[i];
    }
    sum_of_bits === in;
}

/*
 * Reconstructs `out` from `b` bits, given by `bits`.
 * Least significant bit in `bits[0]`.
 */
template Bits2Num(b) {
    signal input bits[b];
    signal output out;
    var lc = 0;

    for (var i = 0; i < b; i++) {
        lc += (bits[i] * (1 << i));
    }
    out <== lc;
}

/*
 * Checks if `in` is zero and returns the output in `out`.
 */
template IsZero() {
    signal input in;
    signal output out;

    signal inv;

    inv <-- in!=0 ? 1/in : 0;

    out <== -in*inv +1;
    in*out === 0;
}

/*
 * Checks if `in[0]` == `in[1]` and returns the output in `out`.
 */
template IsEqual() {
    signal input in[2];
    signal output out;

    component isz = IsZero();

    in[1] - in[0] ==> isz.in;

    isz.out ==> out;
}

/*
 * Checks if `in[0]` < `in[1]` and returns the output in `out`.
 */
template LessThan(n) {
    assert(n <= 252);
    signal input in[2];
    signal output out;

    component n2b = Num2Bits(n+1);

    n2b.in <== in[0]+ (1<<n) - in[1];

    out <== 1-n2b.bits[n];
}

/////////////////////////////////////////////////////////////////////////////////////
///////////////////////// Templates for this lab ////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

/*
 * Outputs `out` = 1 if `in` is at most `b` bits long, and 0 otherwise.
 */
template CheckBitLength(b) {
    assert(b < 254);
    signal input in;
    signal output out;

    // Num2Bits(b) without assertion
    signal output bits[b];
    for (var i = 0; i < b; i++) {
        bits[i] <-- (in >> i) & 1;
        bits[i] * (1 - bits[i]) === 0;
    }
    var sum_of_bits = 0;
    for (var i = 0; i < b; i++) {
        sum_of_bits += (2 ** i) * bits[i];
    }

    component eq = IsEqual();
    eq.in[0] <== in;
    eq.in[1] <== sum_of_bits;
    out <== eq.out;
}

/*
 * Enforces the well-formedness of an exponent-mantissa pair (e, m), which is defined as follows:
 * if `e` is zero, then `m` must be zero
 * else, `e` must be at most `k` bits long, and `m` must be in the range [2^p, 2^p+1)
 */
template CheckWellFormedness(k, p) {
    signal input e;
    signal input m;

    // check if `e` is zero
    component is_e_zero = IsZero();
    is_e_zero.in <== e;

    // Case I: `e` is zero
    //// `m` must be zero
    component is_m_zero = IsZero();
    is_m_zero.in <== m;

    // Case II: `e` is nonzero
    //// `e` is `k` bits
    component check_e_bits = CheckBitLength(k);
    check_e_bits.in <== e;
    //// `m` is `p`+1 bits with the MSB equal to 1
    //// equivalent to check `m` - 2^`p` is in `p` bits
    component check_m_bits = CheckBitLength(p);
    check_m_bits.in <== m - (1 << p);

    // choose the right checks based on `is_e_zero`
    component if_else = IfThenElse();
    if_else.cond <== is_e_zero.out;
    if_else.L <== is_m_zero.out;
    //// check_m_bits.out * check_e_bits.out is equivalent to check_m_bits.out AND check_e_bits.out
    if_else.R <== check_m_bits.out * check_e_bits.out;

    // assert that those checks passed
    if_else.out === 1;
}

/*
 * Right-shifts `b`-bit long `x` by `shift` bits to output `y`, where `shift` is a public circuit parameter.
 */
template RightShift(b, shift) {
    assert(shift < b);
    signal input x;
    signal output y;

    y <-- x >> shift;

    component bits_x = Num2Bits(b);
    bits_x.in <== x;
    component bits_y = Num2Bits(b - shift);
    bits_y.in <== y;

    for (var i = 0; i < b - shift; i++) {
        bits_x.bits[i + shift] === bits_y.bits[i];
    }
}

/*
 * Rounds the input floating-point number and checks to ensure that rounding does not make the mantissa unnormalized.
 * Rounding is necessary to prevent the bitlength of the mantissa from growing with each successive operation.
 * The input is a normalized floating-point number (e, m) with precision `P`, where `e` is a `k`-bit exponent and `m` is a `P`+1-bit mantissa.
 * The output is a normalized floating-point number (e_out, m_out) representing the same value with a lower precision `p`.
 */
template RoundAndCheck(k, p, P) {
    signal input e;
    signal input m;
    signal output e_out;
    signal output m_out;
    assert(P > p);

    // check if no overflow occurs
    component if_no_overflow = LessThan(P+1);
    if_no_overflow.in[0] <== m;
    if_no_overflow.in[1] <== (1 << (P+1)) - (1 << (P-p-1));
    signal no_overflow <== if_no_overflow.out;

    var round_amt = P-p;
    // Case I: no overflow
    // compute (m + 2^{round_amt-1}) >> round_amt
    var m_prime = m + (1 << (round_amt-1));
    //// Although m_prime is P+1 bits long in no overflow case, it can be P+2 bits long
    //// in the overflow case and the constraints should not fail in either case
    component right_shift = RightShift(P+2, round_amt);
    right_shift.x <== m_prime;
    var m_out_1 = right_shift.y;
    var e_out_1 = e;

    // Case II: overflow
    var e_out_2 = e + 1;
    var m_out_2 = (1 << p);

    // select right output based on no_overflow
    component if_else[2];
    for (var i = 0; i < 2; i++) {
        if_else[i] = IfThenElse();
        if_else[i].cond <== no_overflow;
    }
    if_else[0].L <== e_out_1;
    if_else[0].R <== e_out_2;
    if_else[1].L <== m_out_1;
    if_else[1].R <== m_out_2;
    e_out <== if_else[0].out;
    m_out <== if_else[1].out;
}

/*
 * Left-shifts `x` by `shift` bits to output `y`.
 * Enforces 0 <= `shift` < `shift_bound`.
 * If `skip_checks` = 1, then we don't care about the output and the `shift_bound` constraint is not enforced.
 */
template LeftShift(shift_bound) {
    signal input x;
    signal input shift;
    signal input skip_checks;
    signal output y;

    component less = LessThan(shift_bound);
    less.in[0] <== shift;
    less.in[1] <== shift_bound;

    component junc = IfThenElse();
    junc.cond <== skip_checks;
    junc.R <== less.out;
    junc.L <== 1;
    junc.out === 1;

    y <-- x << shift;

    // TODO: enforce y
}

/*
 * Find the Most-Significant Non-Zero Bit (MSNZB) of `in`, where `in` is assumed to be non-zero value of `b` bits.
 * Outputs the MSNZB as a one-hot vector `one_hot` of `b` bits, where `one_hot`[i] = 1 if MSNZB(`in`) = i and 0 otherwise.
 * The MSNZB is output as a one-hot vector to reduce the number of constraints in the subsequent `Normalize` template.
 * Enforces that `in` is non-zero as MSNZB(0) is undefined.
 * If `skip_checks` = 1, then we don't care about the output and the non-zero constraint is not enforced.
 */
template MSNZB(b) {
    signal input in;
    signal input skip_checks;
    signal output one_hot[b];

    component iszero = IsZero();
    iszero.in <== in;
    iszero.out === skip_checks;

    component bits_in = Num2Bits(b);
    bits_in.in <== in;

    signal flags[b+1];
    flags[0] <== 0;
    component juncs[b];
    for (var i = 0; i < b; i++) {
        juncs[i] = IfThenElse();
        juncs[i].cond <== flags[i];
        juncs[i].L <== 1;
        juncs[i].R <== bits_in.bits[b - i - 1];
        flags[i + 1] <== juncs[i].out;

        one_hot[b - i - 1] <== bits_in.bits[b - i - 1] * (1 - flags[i]);
    }
}

/*
 * Normalizes the input floating-point number.
 * The input is a floating-point number with a `k`-bit exponent `e` and a `P`+1-bit *unnormalized* mantissa `m` with precision `p`, where `m` is assumed to be non-zero.
 * The output is a floating-point number representing the same value with exponent `e_out` and a *normalized* mantissa `m_out` of `P`+1-bits and precision `P`.
 * Enforces that `m` is non-zero as a zero-value can not be normalized.
 * If `skip_checks` = 1, then we don't care about the output and the non-zero constraint is not enforced.
 */
template Normalize(k, p, P) {
    signal input e;
    signal input m;
    signal input skip_checks;
    signal output e_out;
    signal output m_out;
    assert(P > p);

    component iszero = IsZero();
    iszero.in <== m;
    iszero.out === skip_checks;

    component msnzb = MSNZB(P + 1);
    msnzb.in <== m;
    msnzb.skip_checks <== skip_checks;

    signal parts[P + 2];
    parts[0] <== 0;
    for (var i = 0; i < P + 1; i++) {
        parts[i + 1] <== parts[i] + i * msnzb.one_hot[i];
    }
    signal ell <== parts[P + 1];

    component left_shift = LeftShift(P + 1);
    left_shift.x <== m;
    left_shift.shift <== P - ell;
    left_shift.skip_checks <== skip_checks;
    m_out <== left_shift.y;
    e_out <== e + ell - p;
}

/*
 * Adds two floating-point numbers.
 * The inputs are normalized floating-point numbers with `k`-bit exponents `e` and `p`+1-bit mantissas `m` with scale `p`.
 * Does not assume that the inputs are well-formed and makes appropriate checks for the same.
 * The output is a normalized floating-point number with exponent `e_out` and mantissa `m_out` of `p`+1-bits and scale `p`.
 * Enforces that inputs are well-formed.
 */
template FloatAdd(k, p) {
    signal input e[2];
    signal input m[2];
    signal output e_out;
    signal output m_out;

    component checks[2];
    for (var i = 0; i < 2; i++) {
        checks[i] = CheckWellFormedness(k, p);
        checks[i].e <== e[i];
        checks[i].m <== m[i];
    }

    // arrange numbers in the order of their magnitude
    component cmp = LessThan(k + p + 1);
    for (var i = 0; i < 2; i++) {
        cmp.in[i] <== m[i] + e[i] * (1 << (p + 1));
    }

    component e_junc = Switcher();
    e_junc.sel <== cmp.out;
    e_junc.L <== e[0];
    e_junc.R <== e[1];

    component m_junc = Switcher();
    m_junc.sel <== cmp.out;
    m_junc.L <== m[0];
    m_junc.R <== m[1];

    var alpha_m = m_junc.outL;
    var alpha_e = e_junc.outL;
    var beta_m = m_junc.outR;
    var beta_e = e_junc.outR;

    var diff_e = alpha_e - beta_e;
    component diff_e_less = LessThan(k);
    diff_e_less.in[0] <== p + 1;
    diff_e_less.in[1] <== diff_e;

    component alpha_e_zero = IsZero();
    alpha_e_zero.in <== alpha_e;

    component or_e = OR();
    or_e.a <== diff_e_less.out;
    or_e.b <== alpha_e_zero.out;

    component junc_alpha_m = IfThenElse();
    junc_alpha_m.cond <== or_e.out;
    junc_alpha_m.L <== 1;
    junc_alpha_m.R <== alpha_m;

    component junc_diff = IfThenElse();
    junc_diff.cond <== or_e.out;
    junc_diff.L <== 0;
    junc_diff.R <== diff_e;

    component junc_beta_e = IfThenElse();
    junc_beta_e.cond <== or_e.out;
    junc_beta_e.L <== 1;
    junc_beta_e.R <== beta_e;

    component m_alpha_lsh = LeftShift(p + 2);
    m_alpha_lsh.x <== junc_alpha_m.out;
    m_alpha_lsh.shift <== junc_diff.out;
    m_alpha_lsh.skip_checks <== 0;

    component norm = Normalize(k, p, 2 * p + 1);
    norm.e <== junc_beta_e.out;
    norm.m <== m_alpha_lsh.y + beta_m;
    norm.skip_checks <== 0;

    component round = RoundAndCheck(k, p, 2 * p + 1);
    round.e <== norm.e_out;
    round.m <== norm.m_out;

    component junc_m = IfThenElse();
    junc_m.cond <== or_e.out;
    junc_m.L <== alpha_m;
    junc_m.R <== round.m_out;

    component junc_e = IfThenElse();
    junc_e.cond <== or_e.out;
    junc_e.L <== alpha_e;
    junc_e.R <== round.e_out;

    e_out <== junc_e.out;
    m_out <== junc_m.out;
}
