# Flipping bits to arbitrary CRC values

Nam Nguyen<br/>
2020-10-10

## Abstract

This short paper describes a simple algorithm to select from several chosen
bits of a message to flip in order to obtain any desired cyclic redundancy
check (or CRC) value.

## Background

### CRC implementation

CRC is often implemented in software with a lookup table. The usually model is
given in [Rocksoft Model CRC Algorithm][1]. There are several parameters to
the model:

1. The width of the polynomial.
1. The value of the polynomial.
1. The initial value for the register.
1. Whether each input byte is reflected before processing.
1. Whether the final register value should be reflected.
1. The value to XOR (exclusive-or) with the final register value.

Parameter 1, 2, and 4 determine the values in the lookup table.

Parameter 3 is akin to a xor-in value with the register initialized to zero.
This is similar to parameter 6, a xor-out parameter.

Parameter 5 is not interesting to our discussion here.

Under the lookup table method, an input byte is combined with the current
register value to lookup the corresponding pre-calculated value from the table.
This value is then used to update the register. The final register value might
be reversed before being XOR'd with the xor-out value.

Combining the xor-in value, the processing, and the xor-out value, [the CRC of
a message in terms of three components][2] are shown below:

    CRC(m) = i ^ process(m) ^ o

where `i` is due to the xor-in value, `o` the xor-out.

The interesting aspect of the processing part is its linearity. That is, given
two messages `m_1` and `m_2` of the same length, `process(m_1 ^ m_2)` yields
the same value as `process(m_1) ^ process(m_2)`. This property is seen under
the [modulo arithmetic view of CRC functions][3] (i.e.
`(a + b) mod m = ((a mod m) + (b mod m)) mod m`).

### Affinity

CRC is [affine with respect to the XOR operation][4], i.e. given messages
`m_1`, `m_2`, and `m_3` of the same length:

    CRC(m_1) ^ CRC(m_2) ^ CRC(m_3) = CRC(m_1 ^ m_2 ^ m_3)

A sketch proof looks like this:

    CRC(m_1) = i ^ process(m_1) ^ o
    CRC(m_2) = i ^ process(m_2) ^ o
    CRC(m_3) = i ^ process(m_3) ^ o

    CRC(m_1) ^ CRC(m_2) ^ CRC(m_3)
        =   i ^ process(m_1) ^ o
          ^ i ^ process(m_2) ^ o
          ^ i ^ process(m_3) ^ o
        =   i ^ process(m_1) ^ process(m_2) ^ process(m_3) ^ o
        =   i ^ process(m_1 ^ m_2 ^ m_3) ^ o  # due to linearity of processing
        =   CRC(m_1 ^ m_2 ^ m_3)

## CRC values of a message...

### ... with one bit flipped

Affinity presents a way to calculate the CRC value of the original message with
one bit (or several bits) flipped. Let `b` the blank message of all zero bits.
Let `s` be the same blank message with one bit set at a desired location. Both
`b` and `s` are of the same length as the original message `m`. Due to affine
transformation:

    CRC(m ^ b ^ s) = CRC(m) ^ CRC(b) ^ CRC(s)

Since `CRC(m)` is given, and `CRC(b)` and `CRC(s)` can be calculated without
access to `m`, the CRC value of `m` with one bit flipped at the same position
as the set bit in `s` can be calculated.

### ... with several bits flipped

The same approach can be extended to flip multiple bits. For example, to
calculate the CRC value of the original message with 3 bits flipped somewhere:

    CRC(m ^ b ^ s_1 ^ b ^ s_2 ^ b ^ s_3) =
        CRC(m) ^ CRC(b) ^ CRC(s_1) ^ CRC(b) ^ CRC(s_2) ^ CRC(b) ^ CRC(s_3)

where `s_1`, `s_2`, and `s_3` are blank messages with one bit set at desired
locations.

## Flipping bits to desired values

### Formulating the problem

The previous section brings up an opportunity to flip some bits to obtain
desired values.

Let `t` be the target value, `p_1` ... `p_n` are the bit positions that can
be flipped. The problem is to pick a subset of positions to flip in order to
achieve the CRC value of `t`.

Each position `p_i` yields one value for `c_i = CRC(b) ^ CRC(s_i)` where `s_i`
is the blank message with the bit in position `p_i` set, and `c_i` is the
combined XOR value of the CRC values of the blank message and `s_i`.

Assuming that a subset `{i, j, ...}` is found, then:

    CRC(m ^ b ^ s_i ^ b ^ s_j ...) =
        CRC(m) ^ CRC(b) ^ CRC(s_i) ^ CRC(b) ^ CRC(s_j) ... = t

or

    c_i ^ c_j ... = t ^ CRC(m) = d

In other words, the subset is one whose combined XOR value is `t ^ CRC(m)`.
Hence the problem can be stated simply: given a desired value `d`, and a list
of values, pick a subset of that list so that their combined XOR value is `d`.

### Solving the problem with linear algebra

Assuming that there are `n` numbers `c_1`, `c_2`, ... `c_n`. Each number is
`w`-bit long, where `c_i1` is the least significant bit (LSB), and `c_iw` is
the most significant bit (MSB) of `c_i`. Similarly, `d_1` is the LSB and `d_w`
the MSB of `d`.

Let `x_i` be `0` if `c_i` is not in the selected set, and `1` if `c_i` is. Put
differently, if `x_i` is set, the bit at position `p_i` is flipped. The
selected set will have to satisfy:

    c_1 * x_1 XOR c_2 * x_2 XOR ... XOR c_n * x_n = d

At individual bit level, that equation is equivalent to a system of equations:

    c_11 AND x_1 XOR c_21 AND x_2 XOR ... XOR c_n1 AND x_n = d_1
    c_12 AND x_1 XOR c_22 AND x_2 XOR ... XOR c_n2 AND x_n = d_2
    ...
    c_1w AND x_1 XOR c_2w AND x_2 XOR ... XOR c_nw AND x_n = d_w

Under the Galois Field GF(2), where multiplication is bitwise AND, and addition
is bitwise XOR, the above system is algebraically familiar:

    c_11 * x_1 + c_21 * x_2 + ... + c_n1 * x_n = d_1
    c_12 * x_1 + c_22 * x_2 + ... + c_n2 * x_n = d_2
    ...
    c_1w * x_1 + c_2w * x_2 + ... + c_nw * x_n = d_w

Let `A` be a matrix formed by horizontally stacking `c_1`, ..., `c_n`, and `d`
be the binary column vector representing its own value. Then the problem is to
solve for a binary column vector `x` such that `Ax = d`. This can be solved
with regular linear algebra (e.g. Gaussian elimination and back solving) under
GF(2). Below is a bad ASCII art of the setup with 7 5-bit `c` values, i.e. 7
bits can be flipped and the CRC width is 5 bits:

                                             [ x_1
    [ c_11 c_21 c_31 c_41 c_51 c_61 c_71 ]     x_2     [ d_1
    [ c_12 c_22 c_32 c_42 c_52 c_62 c_72 ]     x_3       d_2
    [ c_13 c_23 c_33 c_43 c_53 c_63 c_73 ] @   x_4   =   d_3
    [ c_14 c_24 c_34 c_44 c_54 c_64 c_74 ]     x_5       d_4
    [ c_15 c_25 c_35 c_45 c_55 c_65 c_75 ]     x_6       d_5 ]
                                               x_7 ]

### Algorithm

Finally, the algorithm is as followed:

Inputs:

1. The exact CRC function
1. The width `w` of that CRC function
1. `CRC(m)`
1. Length of `m` in bits
1. A set of `n` positions `p_1` ... `p_n` of flippable bits
1. `t` the target CRC value

Steps:

1. Prepare a blank message `b` of the same length as `m`, and calculate
   `CRC(b)`.
1. For each bit position `p_i`:
    1. Construct `s_i`, a blank message with one bit at position `p_i` set.
    1. Calculate `c_i = CRC(b) ^ CRC(s_i)`.
1. Form bit matrix `A` with `w` rows and `n` columns by horizontally stacking
   all `c_i`s.
1. Form `w`-element bit vector `d` from `CRC(m) ^ t`.
1. Solve for `n`-element bit vector `x` such that `Ax = d`.

Outputs:

1. For each element `x_i` in vector `x`, if `x_i` is set, the bit at position
   `p_i` is picked to flip.

### Matching multiple CRC functions simultaneously

The same algorithm can be easily extended to match multiple CRC values from
various CRC functions all at once. Two simple changes are noted here.

1. A wrapping function that produces a longer checksum value by concatenating
   all values from all CRC functions. This function is used in place of the
   original CRC function in the algorithm above.
1. The same bit concatenation is applied to multiple `t`s to produce `d`.

It goes without saying that `w` is now extended to be the sum of all CRC width
parameters.

## Conclusion

Exploiting affinity of CRCs gives a simple method to select a set of bits to
flip so that the resulting message has the desired CRC value.

[1]: <https://zlib.net/crc_v3.txt> "A PAINLESS GUIDE TO CRC ERROR DETECTION
ALGORITHMS by Ross N. Williams"

[2]: <https://www.cosc.canterbury.ac.nz/greg.ewing/essays/CRC-Reverse-Engineering.html>
"Reverse-Engineering a CRC Algorithm by Gregory Ewing"

[3]: <https://en.wikipedia.org/wiki/Mathematics_of_cyclic_redundancy_checks>
"Mathematics of cyclic redundancy checks by Wikipedia"

[4]: <https://www.ndss-symposium.org/wp-content/uploads/2020/04/bar2020-23011.pdf>
"It Doesn't Have to Be So Hard: Efficient Symbolic Reasoning for CRCs by
Vaibhav Sharma & Navid Emamdoost & Seonmo Kim & Stephen McCamant"
