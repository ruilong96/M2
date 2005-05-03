--- status: Draft
--- author(s): DPS 
--- notes: 

document { 
     Key => {pfaffians, (pfaffians,ZZ,Matrix)},
     Headline => "ideal generated by Pfaffians",
     Usage => "pfaffians(n,M)",
     Inputs => {"n" => ZZ => "the size of the Pfaffians",
	  "M" => Matrix => "which is skew-symmetric, and whose ring is an integral domain"
	  },
     Outputs => {Ideal=>{"the ideal generated by the Pfaffians of the ", TT "n", " by ", 
	  TT "n", " principal submatrices of ", TT "M"}
	  },
     Consequences => {
	  },     
     "The determinant of a skew symmetric matrix ", TT "N", ", that is ", 
     TT "transpose(N) + N == 0", " is always a perfect square whose 
     squareroot is called the Pfaffian of ", TT "N.",
     EXAMPLE {
	  "R = QQ[a..d];",
      	  "M = genericSkewMatrix(R,a,4)",
      	  "pfaffians(2,M)",
      	  "pfaffians(4,M)"
	  },
     "Pfaffians generate the ideal of an elliptic normal curve in projective Fourspace:",
     EXAMPLE {
	  "R=QQ[x_0..x_4]",
	  "y={0,1,13,-13,-1}",
	  "M=matrix table(5,5, (i,j)-> x_((i+j)%5)*y_((i-j)%5))",
          "I=pfaffians(4,M)",
	  "betti res I"
	  },    
     Caveat => {"The algorithm used is a modified Gaussian reduction/Bareiss algorithm, 
	  which uses division and therefore we must assume that the ring of ", TT "M", "
	  is an integral domain.",
	  PARA,
          "The skew symmetry of ", TT "M", " is not checked, but the algorithm 
	  proceeds as if it were, with somewhat unpredictable results!"
	  },
     SeeAlso => {det, "matrices"}
     }
TEST ///
R=ZZ/101[a..f]
m=genericSkewMatrix(R,a,4)
assert( pfaffians(-2,m) == ideal(0_R) )
assert( pfaffians(0,m) == ideal(1_R) )
assert( pfaffians(1,m) == ideal(0_R) )
assert( pfaffians(2,m) == ideal(a,b,c,d,e,f) )
assert( pfaffians(3,m) == ideal(0_R) )
assert( pfaffians(4,m) == ideal(c*d-b*e+a*f) )
///
