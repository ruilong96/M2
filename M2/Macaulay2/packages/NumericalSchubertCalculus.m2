newPackage(
    "NumericalSchubertCalculus",
    Version => "0.4", 
    Date => "September 29, 2014",
    Authors => {
	{Name => "Anton Leykin", 
	    Email => "leykin@math.gatech.edu", 
	    HomePage => "http://people.math.gatech.edu/~aleykin3"},
	{Name => "Abraham Martin del Campo", 
	    Email => "asanchez@math.tamu.edu", 
	    HomePage => "http://www.math.tamu.edu/~asanchez"},
	{Name => "Jan Verschelde",
		Email => "jan@math.uic.edu",
		HomePage => "http://www.math.uic.edu/~jan/"}
	},
    Headline => "a Macaulay2 package for using numerical methods in Schubert Calculus",
--    PackageExports => {
--	"NAGtypes"
--	},
    PackageImports => {
	"PHCpack",
	"NumericalAlgebraicGeometry"
	},
    AuxiliaryFiles => true,
    DebuggingMode => true
    )

export {   
   NSC'DBG, NSC'VERIFY'SOLUTIONS, NSC'BLACKBOX, setFlags,
   trackHomotopy,
   redChkrPos,
   moveRed,
   moveCheckers,
   playCheckers,
   Board,
   IsResolved,
   Fathers,
   Children,
   printTree,
   makeLocalCoordinates,
   FlagM,
   CriticalRow,
   Polynomials,
   Solutions,
   solveSchubertProblem,
   changeFlags, -- temporary
   makePolynomials, -- temporary
   SolutionsSuperset, -- temporary
   solutionToChart,--temporary 06.04.14
   MovingFlag'at'Root,
   columnReduce
   }

-- NC means no checker in that column
NC = infinity

-- OUR FIELD
FFF = QQ
FFF = RR
FFF = CC
--FFF = CC_53
ERROR'TOLERANCE = 0.001
NEWTON'TOLERANCE = 10^-10
------------------
-- Debug Level --
------------------
-- 0 = no debug mode
-- 1 = print progress info and time main processes
-- 2 = ... + checkerboard steps info
-- >2 = new experimental stuff kicks in
DBG = 0
VERIFY'SOLUTIONS = true
BLACKBOX = false

setFlags = method(Options=>{NSC'DBG=>null,NSC'VERIFY'SOLUTIONS=>null,NSC'BLACKBOX=>null})
installMethod(setFlags, o -> () -> scan(keys o, k->if o#k=!=null then
	if k === NSC'DBG then DBG = o#k
	else if k === NSC'VERIFY'SOLUTIONS then VERIFY'SOLUTIONS = o#k
	else if k === NSC'BLACKBOX then BLACKBOX = o#k
	))

 
load "NumericalSchubertCalculus/PHCpack-LRhomotopies.m2"

load "NumericalSchubertCalculus/pieri.m2"
load "NumericalSchubertCalculus/service-functions.m2"
load "NumericalSchubertCalculus/galois.m2"

-----------------------------
-- Numerical LR-Homotopies
-----------------------------

---------------------
-- input: two schubert conditions l and m
--			entered as brackets
--		  the Grassmannian G(k,n)
--
-- Output: checkboard coordinates for the 
--         red checkers
---------------------
-- example: for {2,1}*{2} in G(3,6)
--
--partition2bracket({2,1},3,6)
--partition2bracket({2},3,6)
--redChkrPos({2,4,6},{2,5,6},3,6)
--------------------
redChkrPos = method(TypicalValue => List)
redChkrPos(List,List,ZZ,ZZ) := (l,m,k,n) -> (
     -- input the Schubert conditions l and m
     -- as bracket
     -- input the Grassmannian G(k,n)
     m = reverse m;
     board := for i to n-1 list NC;
     redPos := new MutableList from board;
     apply(#l, j -> redPos#(l#j-1) = m#j-1);
     toList redPos
)

--####################
-- "moveRed" moves the red checkers
--
-- input:
--       blackup - Coordinates of the ascending black checker
--       blackdown - Coordinates of the descending black checker
--       redpos - List of red checker positions
--
--	output: {(repos,typeofmove,critrow)} or {(repos1,typeofmove1,critrow),(repos2,typeofmove2,critrow)}
--       redpos - Updated list (of lists) of red checker positions
--       typeofmove - {row,column,split}
--                    a tuple which tells the type of the move we had to perform from
--                    the 3x3 table of moves. This is given as a 
--                    tuple {row,column,split} where split says
--                    if you moved or not the red checkers
--                    (by 0 and 1 respectively) when there was a split
--        critrow - the critical row
moveRed = method(TypicalValue => List)
moveRed(List,List,List) := (blackup, blackdown, redposition) -> (
    ------------------------------------------------
    -- We need to check first if it is a valid configuration
    -- that is why I have been having errors
    ------------------------------------------------
    n := #redposition; -- n is the size of the checkboard
    split:=0;
    critrow := 0;
    critdiag := 0;
    g:=2; -- These are two flags to indicate in which situation we are 
    r:=2;
    indx := new List;
    redpos := new MutableList from redposition;
    -- find the "critical row"
    indx = for i to n-blackdown#0-1 list n-1-i;
    apply(indx, j -> (
	    if redpos#j === blackdown#1 then (
	       	critrow = j;
	       	if j == blackdown#0 then g=0 else g=1;
	  	) 	
     	    ));    
    -- find the "critical diagonal"
    indx= for i to blackdown#0-1 list i;
    indx = reverse indx;
    apply(indx, j->(
	    if blackdown#0-j+redpos#j == n then(
	       	critdiag = j;
	       	if blackup === {j,redpos#j} then r=0 else r=1;
	  	)
     	    ));
    if r == 0 then (
	redpos#(blackup#0)=redpos#(blackup#0)-1;
	if g == 0 then redpos#(blackdown#0) = redpos#(blackdown#0)+1;
	if g == 1 then redpos#critrow = redpos#critrow + 1;
     	) else if r == 1 then (
	if g == 0 then(
	    redpos#critrow = redpos#critdiag;
	    redpos#critdiag = NC;
	    redpos#(blackup#0) = blackdown#1;
	    ) else if g == 1 then(
	    block := 0;
	    blockindx := for i to critrow-1-critdiag-1 list critrow-1-i;
	    apply(blockindx, b -> if redpos#critrow < redpos#b and redpos#b < redpos#critdiag then block = 1);
	    if block != 1 then (
		-- switch the rows of the red checkers in the critical diagonal and row
		-- then, move the left one over to the column of the ascending black
		redpos#critrow = redpos#critdiag;
		redpos#critdiag = NC;
		redpos#(blackup#0) = blackdown#1;
		split = 1;
	       	);
	    );
     	) else if r == 2 and g == 0 then (
	redpos#(blackup#0)=redpos#critrow;
	redpos#critrow = NC;
     	);
    if split == 0 then {(toList redpos,{r,g,split})} else {(redposition,{r,g,0}), (toList redpos,{r,g,split})}
    )

moveCheckers = method(TypicalValue => List)
moveCheckers Array := blackred -> (
     blackposition := first blackred;
     redposition := last blackred;
     n := #redposition; -- n is the size of the board
     splitcount:=0;
     copies:=0;
     -- determine the columns of the descending and ascending black checkers
     -- blackdown1 is the column to the right of the column of the lowest black checker
	 -- blackup1 is the column of the checker that is one row lower than the checker 
	 --        in blackdown1 
     blackdown1 := position(blackposition, x->x == n-1) + 1;
     if blackdown1 == n then return ({},"leaf");
     blackup1 := position(blackposition, x-> x == 1+blackposition#blackdown1);
     -- The column of the right black checker to be sorted goes from desccol 
     -- to the end of the board.
     -- Determine the rows of the next pair of black checkers to be sorted.
	 blackup2 := n-blackdown1+blackup1;
	 blackdown2 := blackup2-1; -- this is the critical row
	 listofredpositions := moveRed({blackup1,blackup2},{blackdown1,blackdown2}, redposition);
	 blackposition = new MutableList from blackposition;
	 blackposition#blackup1 = blackposition#blackup1 - 1;
	 blackposition#blackdown1 = blackposition#blackdown1 + 1;
	 (
	      apply(listofredpositions, r-> [toList blackposition, 
		   	first r, -- new redposition
		   	last r -- new type of move
		   	]), 
	      blackdown2 --return also the critical row
	      )
)


-----------------
-- playCheckers
-----------------
-- Function that gets a specific node and plays
-- a checkerboard game between two varieties X1 and X2
--
-- It sets up the game, and then it uses
-- the combinatorial LR-rule to make deformations
-- between the Schubert variety X2 to X1
-- It stores all the information in a HashTable
-------------------
-- If we want to compute X1\cap X2 \cap X3 \cap...\cap Xn
-- we first play the checkers with X1 and X2
--
-- input1:
--         l1, l2, two partitions (representing X1 and X2)
--         k,n the Grassmannian where they live
-- Output1:
--         Dag - a Hashtable with all the checkermoves played
--
-------------------
playCheckers = method(TypicalValue => MutableHashTable)
playCheckers(List,List,ZZ,ZZ) := (partn1,partn2,k,n) -> (
     all'nodes := new MutableHashTable;
     redChkrs := 
      if partn1 > partn2 then
     	  redChkrPos(partition2bracket(partn2,k,n),partition2bracket(partn1,k,n),k,n)
      else 
          redChkrPos(partition2bracket(partn1,k,n),partition2bracket(partn2,k,n),k,n);
     blackChkrs := reverse toList (0..(n-1)); --initial black positions
     if DBG>0 then print "-- playCheckers";
     if DBG>1 then print([blackChkrs, redChkrs]);
     if DBG>0 then cpu0 := cpuTime();
     root :=playCheckers ([blackChkrs, redChkrs], null, {}, all'nodes);  -- returns the root of the tree
     if DBG>0 then << "-- cpu time = " << cpuTime()-cpu0 << endl;
     if DBG>1 then print VerticalList keys all'nodes;
     root
)

------------------------
-- PlayCheckers will also play the next checkerboard game
-- in the Tournament.
-- Input: 
--       board 
--       father (the checkergame this game came from)
--       typeofmove?
--       all'nodes - the list of games played already
--
-- THIS IS THE RECURSIVE CALL OF PLAYCHECKERS
----------------------------
playCheckers (Array,Thing,List,MutableHashTable) := (board,father,typeofmove,all'nodes) ->(
    -- Document this function!! it is not understandable
    -- all'nodes is a HashTable whose keys are boards,
    -- and this is where we store all nodes that we have
    -- already visited.
    --
    -- Abr started the documentation of this function on Feb 6, 2013
    --------------------------------------------
     node'exists := all'nodes#?board; -- check if we already played this game
     self := if node'exists  
     then all'nodes#board  -- if so, then glue solutions, otherwise, start a new hashtable
     else new MutableHashTable from {
	  Board => board, 
	  IsResolved => false,
	  Fathers => {}
	  };
     if father=!=null then self.Fathers = self.Fathers | {(father,typeofmove)};
     if not node'exists then ( --add the ultimate node part here...
--<< "this is node'exists "<< node'exists<<endl;
	 coordX := makeLocalCoordinates board; -- local coordinates X = (x_(i,j))
     	 if numgens ring coordX > 0 then ( 
     	     (children,c) := moveCheckers board;
     	     self.CriticalRow = c;
     	     self.Children = apply(children, b -> playCheckers (take(b,2),self,last b,all'nodes));
	     );
	 all'nodes#board = self;
	 );
     self
)

printTree = method()
printTree MutableHashTable := node ->(
	print peek node;
	scan(node.Children, c-> printTree c);
)

-----------------
--- makeLocalCoordinates
--
-- This procedure will translate a checker 
-- board configuration into a matrix with
-- 0's, 1's and variables
-----------------
-- input: an array of black and red checkers
--        in the form ( ListofPositionsBlack, ListofPositionsRed)
-- output: a matrix with local coordinates
-----------------
-- example:
-----------------
makeLocalCoordinates = method(TypicalValue => MutableMatrix)
makeLocalCoordinates Array := blackred ->(
  blackposition := first blackred;
  redposition := last blackred;
  VAR := symbol VAR;
  n := #redposition; -- n is the size of the board
  -- we find how many black checkers are in northwest to a given red
  rowsred := sort select(redposition, r->r=!=NC);
  colsred := apply(rowsred, r -> position(redposition, j-> j == r));
  E := new MutableHashTable;
    for r to #rowsred-1 do(
      E#(rowsred#r,r) = 1;
      variablerows := take(blackposition,colsred#r+1);
      variablerows = select(variablerows, b-> b< rowsred#r);
      scan(variablerows, j->(
        if member(j,rowsred) and position(redposition, i-> i == j) < colsred#r then
	  variablerows = delete(j,variablerows);
      ));
      scan(variablerows, col-> (
        E#(col,r)=VAR;
      ));
   );
   x:= symbol x;
   R:=FFF[apply(select(sort keys E, k-> E#k===VAR), k-> x_k)];
   X := mutableMatrix(R,n,#rowsred);
   scan(keys E, k-> X_k = if E#k === 1 then 1 else x_k);
   matrix X
)

load "NumericalSchubertCalculus/LR-resolveNode.m2"



---------------
-- solveSchubertProblem
---------------
-- Function that solves a Schubert problem
-- by first taking two of the conditions,
-- then create a tree (with nodes) by playing a 
-- checker game, then resolve the node numerically
-- using homotopies, and gluing the solutions to each
-- node
---------------
-- input:
--    SchPblm := list of Schubert conditions with general flags
--    k,n := the Grassmannian G(k,n)
--    (option) LinAlgebra [default = true] 
--             move to user flags via Linear Algebra (if false via homotopy continuation)
-- output:
--    list of solutions
---------------
solveSchubertProblem = method(Options=>{LinearAlgebra=>true})
solveSchubertProblem(List,ZZ,ZZ) := o -> (SchPblm,k,n) ->(
    -- SchPblm is a list of sequences with two entries
    -- a partition and a flag
    twoconds := take(SchPblm,2);
    remaining'conditions'flags := drop(SchPblm,2);
    -- take the first two conditions
    l1:=verifyLength(first first twoconds,k);
    l2:=verifyLength(first last twoconds,k);
    F1:=promote(last first twoconds,FFF);
    F2:=promote(last last twoconds,FFF);
    
    Slns:={};
    checkPartitionsOverlap := (l1+reverse l2)/(i->n-k-i);
    if min(checkPartitionsOverlap) < 0 then
       Slns
    else(
	if DBG>1 then print "solveSchubertProblem: transforming flags to (M,Id,...)";
	-- resolveNode expects flags to be the following list:
	--  flagM, Id, F3'....  
	--
	-- we make compute the linear transformations s.t.
	-- A*F1 = FlagM*T1
	-- A*F2 = ID * T2
	ID := id_(FFF^n);
	-- 
	-- There is a fundamental difference between the case
	-- with two or more than two partitions
	--
	LocalFlags1 := {F1,F2};
	flgM := matrix;
	LocalFlags2 := List;
	if #remaining'conditions'flags == 0 then (
	    flgM = ID;
	    LocalFlags2 = {flgM, rsort ID};
	) else (
	    flgM = MovingFlag'at'Root n;
	    LocalFlags2 = {flgM, ID};
	    );
	At1t2 := moveFlags2Flags(LocalFlags1,LocalFlags2);
	A := first At1t2;	    
	-- we update the given flags F3 ... Fm
	-- to F3' .. Fm' where Fi' = A*Fi
	new'remaining'conditions'flags := apply(
	    remaining'conditions'flags, CF->(
		(C,F):=CF;
		(C,A*F)
	    ));
	newDag := playCheckers(l1,l2,k,n);
	resolveNode(newDag, new'remaining'conditions'flags);
	conds := {l1,l2};
	-- resolveNode gives a solution in local coords
	-- of {l1}*{l2} w.r.t {FlagM, Id}
	-- we multiply the solution S by FlagM
	-- and we obtain a solution of the Sch. problem
	-- {l1,...,lm} with respect to
	-- {FlagM, Id, F3',...,Fm'}
	--
	--  we need to make a change of coordinates back to the user-defined flags
	-- that is, send (FlagM,Id)-->(F1,F2), which is done by A^(-1)	
	-------------------------------
	--############ Fork to decide if you want to do
	-- change of flags via homotopy or via Linear Algebra
	-- ########################################
	if o.LinearAlgebra then(
	    Ainv := solve(A,ID);
	    Ainv*flgM*newDag.Solutions
	    )else(
	    -- #### NOW THIS IS BROKEN!! because is was based on wrong math
	    -- we need to use homotopy to transform the solutions to the
	    -- user defined flags.
	    --
	    -- A is the matrix above such that
	    --          A*F1 = FlagM*T1 (representing the same flag as F1)
	    --          A*F2 = ID*T2 (representing the same flag as F2)
	    --LocalFlags1 := {F1,F2}; 
	    --LocalFlags2:= {flgM,ID};
	    T1 := At1t2_1;    
	    T2 := At1t2_2;    
	    scan(remaining'conditions'flags, c-> (
		    conds = append(conds, first c);
		    LocalFlags2 = append(LocalFlags2, A*(last c));
		    LocalFlags1 = append(LocalFlags1, last c);
		    ));
    	    if DBG>1 then (
	    	print "solutions obtained at the root of a node";
	    	print newDag.Solutions;    	    	
	    	print "this are the transformations that we apply";
		print "before calling changeFlags:";
		print(flgM);
	    	print(flgM*newDag.Solutions);
	    	);
	    changeFlags(flgM*newDag.Solutions, -- these are matrices in absolute coordinates
	    	(conds, LocalFlags2, LocalFlags1)
		)
	    )
	)
    )-- end of solveSchubertProblem

----------------------------
-- changeCoordsSolutions
----------------------------
-- !!! this function should be removed!!!
changeCoordsSolutions = method()
changeCoordsSolutions Matrix := MX ->(
    k := numcols MX;
    n := numrows MX;
    a := symbol a;
    RMX := ring MX;
    indx:= subsets(0..n-1,k)/toSequence;
    Vars := apply(indx, i-> a_(i));
    R:= (coefficientRing RMX)[Vars, gens RMX];
    G := mutableIdentity(R,n);
    scan(indx, i->G_i=a_i);
    --s:= mutableMatrix random(FFF^n,FFF^k);
    Temp:=entries transpose MX;
    zeroes:=apply(Temp, t->position(t, i-> i==1));
    s := transpose matrix apply(zeroes, i->(
	    cl:=for j from 0 to i list 1;
	    cl2:=for j from i to n-1 list 0;
	    cl|drop(cl2,1)	    
	    ));
    f:=flatten entries(matrix G*sub(s,R)-sub(MX,R));
    nk := n*k;
    numParameters := #Vars+#gens RMX;
    A:= map(FFF^nk, FFF^numParameters, (i,j)-> (f#i)_(R_j));
    b := map(FFF^nk, FFF^1, (i,j)-> -(f#i)_(1_R));
    X := solve(A,b, ClosestFit=>true);
    Vals:=take(flatten entries X, #Vars); -- take a_(i,j) coordinates
    scan(#indx, i->G_(indx#i) = Vals#i);
    sub(matrix G, coefficientRing RMX)
    )

--------- March 24, 2013
-- created a linear homotopy
-- from one set of flags to another
-- by changing column by column
-- for each of the flags 
--
-- Later, we can speed up a little
-- by just creating the homotopy
-- between the flags, by changing
-- only the relevant parts of the 
-- flag...
--------------------------
---------------------------------
--- changeFlags
---------------------------------
---
-- changeFlags is a function to
-- write solutions written w.r.t. flagsA
-- to solutions written w.r.t flagsB
--
-- Input:
--    MX -- X -> A localization pattern, M -> flag (Information about the 
--    	      first two flags determines the localization pattern X)
--    solutionsA -> solutions to the problem specialized to flagsA
--    conds'A'B -> sequence with conditions and flags as follows: 
--    	  conditions = list of partitions (L3,..., Lm), _not_pairs (partition, flag)
--    	  flagsA = (A3,...,Am)
--    	  flagsB = (B3,...,Bm)
-- Output:
--    List of solutions written w.r.t flags B
---------------------------------
solutionToChart = method() -- writes s (a matrix solution) in terms the chart MX (as a list of values of the parameters)
solutionToChart(Matrix, Matrix) := (s,MX) -> (
    k := numcols s;
    n := numrows s;
    a := symbol a;
    RMX := ring MX;
    R := (coefficientRing RMX)[a_(1,1)..a_(k,k),gens RMX];
    G := genericMatrix(R,k,k);
    f := flatten entries(s*G - sub(MX,R)); -- linear system in nk vars 
    nk := n*k;
    nParameters := k^2+#gens RMX; -- number of parameters in f
    A := map(FFF^nk,FFF^nParameters,(i,j)->(f#i)_(R_j));
    b := map(FFF^nk,FFF^1,(i,j)->-(f#i)_(1_R));
    X := solve(A,b, ClosestFit=>true);
    drop(flatten entries X, k*k) -- drop a_(i,j) coordinates
    )
changeFlags = method()
changeFlags(List, Sequence) := (solutionsA, conds'A'B)->( -- solutionsA is a list of matrices
   if #solutionsA == 0 then return {};
   (conditions,flagsA,flagsB) := conds'A'B; 
   SchA := apply(#conditions, i->(conditions#i,flagsA#i));
   SchB := apply(#conditions, i->(conditions#i,flagsB#i));
   -- August 20, 2013:
   -------------------
   -- commenting th checkIncidenceSolutions check as we discovered
   -- this is a test that is numerical unstable!
   --assert all(solutionsA, s->checkIncidenceSolution(s,SchA));
   s := first solutionsA;
   n := numrows s;
   k := numcols s;
   x := symbol x;
   R := FFF[x_(1,1)..x_(k,n-k)];
   MX := sub(random(FFF^n,FFF^n),R)*(transpose genericMatrix(R,k,n-k)||id_(FFF^k)); -- random chart on G(k,n)
   -- THE SOLUTIONS MIGHT NOT FIT MX (that's why I have an error for some problems)
   solutionsB := changeFlags(MX,solutionsA/(s->solutionToChart(s,MX)),conds'A'B);
   -- the following clean is a hack, instead, we need to do a newton step check
   -- when we all changeFlags as there is a numerical check in there... 
   -- the following is a hack
   ret := apply(solutionsB, s-> clean(ERROR'TOLERANCE^2,sub(MX, matrix{s})));
   --assert all(ret, s->checkIncidenceSolution(s,SchB));
   ret
   )

---------------------------------
-- DOCUMENT THIS FUNCTION!!!
--
-- This function is doing a parameter homotopy
-- change one column at a time to move solutions
-- w.r.t. flags A to solutions w.r.t. flags B
----------------------------------
changeFlags(Matrix, List, Sequence) := (MX, solutionsA, conds'A'B)->( -- solutionsA is a list of lists (of values for the parameters)
   (conditions,flagsA,flagsB) := conds'A'B; 
   solutionsS := solutionsA;
   if solutionsA!={} then(
       t:= symbol t;
       n := numcols last flagsA;
       R := ring last flagsA;
       R1 := R[t];
       Mt := matrix{{t}};
       Mt1 := matrix{{1-t}};
        scan(n, i->(
	       -- start when t = 0, target when t = 1
	       flagsHomot := apply(#flagsA, f-> (
		       FlagBB := sub(flagsB#f,R1);
		       FlagAA := sub(flagsA#f,R1);
		       FlagBB_{0..i-1}|
		       (FlagBB_{i}*Mt - FlagAA_{i}*Mt1)|
		       FlagAA_{i+1..n-1}
		       ));
	       RMx := ring MX;
	       m := numgens RMx;
       	       R2 := (coefficientRing RMx)[t,gens RMx];
	       Polys := flatten entries squareUpPolynomials(m, makePolynomials(sub(MX,R2),conditions,flagsHomot));
	       A0 := map(RMx,R2,prepend(0_RMx,gens RMx));
	       A1 := map(RMx,R2,prepend(1_RMx, gens RMx));
	       solutionsT:=track(Polys/A0, Polys/A1, solutionsS, 
		   NumericalAlgebraicGeometry$gamma=>exp(2*pi*ii*random RR));
      	       solutionsS = solutionsT/coordinates;
	       ));
       );
   solutionsS
   )


TEST ///
---------
-- Test the function changeFlags that
-- moves solutions wrt flags A
-- to solutions wrt flags B
--
-- This function doesn't really test if they are actual solutions
-----------------
-- If you want to run this example:
-- 1.- you need to uncomment it AFTER loading NumericalSchubertCalculus package
-- 2.- you need to load the NumercialAlgebraicGeometry package
-- 3.- you need to manually load the function makePolynomials
-- 4.- you need to manually load the function changeFlags
-- 5.- you need to manually load the function changeflagsLinear
--
-- You could avoid all this maybe if you can run this example at the end of
-- the code, where the other examples are.
-----------------
--
debug needsPackage "NumericalSchubertCalculus"
needsPackage "NumericalAlgebraicGeometry"
Rng = FFF[x_{1,1}, x_{1,2}];
MX = matrix{{x_{1,1}, x_{1,2}}, {1,0}, {0,1}, {0,0}};
conds = {{1},{1}};
Flags1 = {random(FFF^4,FFF^4), random(FFF^4,FFF^4)};
sols = solveSystem (makePolynomials(MX, apply(#conds,i->(conds#i,Flags1#i))))_*
Flags2 = {id_(FFF^4)_{1,3,0,2}, rsort id_(FFF^4)} --we should get (0,0) as solution
solsT = changeFlags(MX, sols/coordinates, (conds, Flags1, Flags2))
assert(clean_0.0001 matrix solsT == 0) -- check that the solutions are actually (0,0)
/// --end of TEST

--------------------------
-- toRawSolutions
--
-- Need to document this function
-------------------------
toRawSolutions = method()
toRawSolutions(Matrix,Matrix) := (coordX,X) -> (
     a := flatten entries coordX;
     b := flatten entries X;
     delete(null, apply(#a, i->if a#i == 1 or a#i == 0 then null else b#i))
     )

------------------
-- normalizeColumn
------------------
--  this function divide a specific column of a matrix
--  by a specific value
------------------
-- Input:
--     X'' - the matrix to be normalized
--     r   - the row of the elt that becomes 1
--     j - the column to be normalized
-----------------
normalizeColumn = method(TypicalValue => Matrix)
normalizeColumn(Matrix,ZZ,ZZ) := (X,r,j) -> (  
     k := numgens source X;
     if j=!=null then(
	  X = X_{0..j-1} | (1/X_(r,j))*X_{j}  | X_{j+1..k-1}; 
	  --X''_(r,j) =-1/(1+X_(r,j)); -- error in Ravi's notes: should be -X_(r+1,j)/(1+X_(r,j))
	  --X''_(r+1,j) = 1; -- this is correct, but is also already taken care of 
	  );
     matrix X
     )

-----------------
-- redCheckersColumnReduce
-----------------
-- This function reduce specific column
-- using elementary column operations
-----------------
redCheckersColumnReduce = method(TypicalValue => Matrix)
redCheckersColumnReduce(Matrix, MutableHashTable) := (X'', father) -> (
     k := numgens source X'';
     n := numgens target X'';
     red := delete(NC,last father.Board);
     redSorted := sort red;
     r := father.CriticalRow;
     j := position(redSorted, i-> i==r+1);
     if j=!=null then(
     	  X''  = mutableMatrix X'';
	  crit'col := position(red, i->i==r+1);
     	  for jj from j+1 to k-1 do 
	  -- reduce the columns for red checkers that have higher number and "see" the red checker in the row r+1
     	  if position(red, i->red#jj == i) > crit'col then ( 
	       c := X''_(r+1,jj)/X''_(r+1,j); 
	       scan(n, i->X''_(i,jj) = X''_(i,jj) - c*X''_(i,j))
	       )
	  );
     matrix X''
     )

redCheckersColumnReduceSwap = method(TypicalValue => Matrix)
redCheckersColumnReduceSwap(Matrix, MutableHashTable) := (X'', father) -> (
     k := numgens source X'';
     n := numgens target X'';
     red := delete(NC,last father.Board);
     redSorted := sort red;
     r := father.CriticalRow;
     j := position(redSorted, i-> i>=r+1);
     rowj := redSorted#j; -- the row of the lower swapped red checker (in the father)
     if j=!=null then(
     	  X''  = mutableMatrix X'';
	  for jj from j+1 to k-1 do(
	       -- reduce the columns for red checkers that have higher number and "see" the red checker in the row r+1
	       scan(n, i-> (
	       		 X''_(i,jj) = X''_(i,jj) - X''_(rowj,jj)*X''_(i,j);
	       		 ));
	       )
     	  );
     matrix X''
     )

redCheckersColumnReduce2 = method(TypicalValue => Matrix)
redCheckersColumnReduce2(Matrix, MutableHashTable) := (X'', father) -> (
     k := numgens source X'';
     n := numgens target X'';
     X''  = mutableMatrix X'';
     red := delete(NC,last father.Board);
     redSorted := sort red; -- numbers of the rows where red checkers are
     apply(#redSorted, r->( -- column r is to be reduced 
--	 -- find the redcheckers bellow that can see the current redChecker
--	 witnessReds:=select(drop(red,r), i->i>red#r);
--	 j:={};
--         scan(witnessReds, i-> j=append(j,position(redSorted, l-> l==i)));
     	 col'of'r'on'board := position(last father.Board, i->i==redSorted#r); 
	 reducers := select(0..r-1, 
	      j->position(last father.Board, i->i==redSorted#j)<col'of'r'on'board
	      );  
	 scan(reducers, j->(
	      		-- reduce the columns for red checkers that have higher number and "see" the red checker in the row r+1
			scan(n, i-> (
			     	  X''_(i,r) = X''_(i,r) - X''_(redSorted#j,r)*X''_(i,j);
			     	  ));
		   	));
	 ));
     matrix X''
     )


-------------------
-- columnReduce
-------------------
-- given a matrix coordX from partitions (lambda1,lambda2)
-- we do column row reduction to the solutions
-------------------
-- input:     S -- matrix of solutions
--    	      	    assumes the matrix lives in the Schubert cell for l with
--                  the standard flag, but not all pivots are 1.
--    	       b -- the bracket corresponding to the standard flag
--    	      	    this is just a list of the parts of the flag that are afected by a partition lambda
--    	      	    (equivalent to a partition with k parts of size <= n-k)
-- output:  Sred  --matrix reduced
-------------------
columnReduce=method(TypicalValue=> Matrix )
columnReduce(Matrix,List) := (S,b)->(
    k := numColumns S;
    n := numRows S;
    -- we use the bracket insted of the partition
    -- b := output2bracket (redcheckers);
    -- b := partition2bracket(l,k,n);
    M:= S;
    apply(k-1, col->(
	    -- editing with respect to the pivot of the (col)th column
	    r := b_(col)-1; --row where the ith pivot is
	    a := S_(r,col); --most likely, this will be 1 (in our application because we always have the standard flag)
	    --rescale the column
	    N := M_{0..col-1}|a^(-1)*M_{col};
	    scan(col+1..k-1, j->(
		    a2 := S_(r,j);
		    N=N|(-a2*N_{col}+M_{j});
		    ));
	   M = N; 
	    ));
    return M
    )

TEST ///
load "NumericalSchubertCalculus/TST/columnReduce.m2"
///    

--##########################################
-----------------
-- makePolynomials
--
-- creates a square zero dimensional system
-- that corresponds to a localization pattern
-- and the list of Schubert conditions
-- together with specified flags.
----------------
-- input:
--     	   MX = global coordinates for an open subset
--     	        of a checkerboard variety (or MX' in the homotopy (in Ravi's notes))
--
--     	    conds = list of pairs (l,F) where l is a Schubert condition and F is a flag
--
-- output:  a matrix of polynomials
-----------------
makePolynomials = method(TypicalValue => Ideal)
makePolynomials(Matrix, List) := (MX, conds) ->(
     R := ring MX;
     k := numgens source MX;
     n := numgens target MX;
     eqs := sum(conds, lF ->(
	       (l,F) := lF;
	       MXF:=MX|sub(F,R);
	       b := partition2bracket(l,k,n);
	       sum(#b, r->( 
			 c := b#r;
			 minors(k+c-(r+1)+1, MXF_{0..k+c-1})
			 ))
     	       ));
     eqs 
)
makePolynomials(Matrix, List, List) := (MX, conds, flagsHomotopy)->(
    R := ring MX;
    k := numcols MX;
    n := numrows MX;
    eqs := sum(#conds, i->(
	    MXF := MX|sub(flagsHomotopy#i,R);
	    b:= partition2bracket(conds#i,k,n);
	    sum(#b,r->(
		    c := b#r;
		    minors(k+c-(r+1)+1, MXF_{0..k+c-1})
		    ))
	    ));
    eqs
    )

-- Document the Following function
---------------------------------
-- squareUpPolynomials
---------------------------------
-- m random linear combinations of generators of the ideal
squareUpPolynomials = method()
squareUpPolynomials(ZZ,Ideal) := (m,eqs) ->  gens eqs * random(FFF^(numgens eqs), FFF^m)  
--squareUpPolynomials(ZZ,Ideal,Ideal) := (m,eqs1,eqs2) ->  (
--    G := random(FFF^(numgens eqs1), FFF^m);
--    (gens eqs1 * G, gens eqs2 * G)
--    )

-----------------------------
-- Tracks a homotopy
-----------------------------
-- Input: 
--    H -- a list of polynomials in k[xx,t];
--    S = {{...},...,{...}} -- a list of solutions to H at t=0
-- Output: 
--    T - a list of Points that are solutions to H at t=1
-- Caveat:
--    H should be a _linear_ in t
trackHomotopy = method(TypicalValue=>List)
trackHomotopy (Matrix,List) := (H,S) -> (
     Rt := ring H;
     R := (coefficientRing Rt)[drop(gens Rt,1)];
     map't'0 := map(R, Rt, matrix{{0_FFF}}|vars R);
     map't'1 := map(R, Rt, matrix{{1_FFF}}|vars R);
     sols := track(first entries map't'0 H, first entries map't'1 H, S
	 , NumericalAlgebraicGeometry$gamma=>exp(2*pi*ii*random RR)
	 );
     if any(sols/status, s->s=!=Regular) then error "trackHomotopy: singularity encountered";
     sols 
     )

------------------------
-- isRedCheckerInRegionE
------------------------
-- NEEDS to be documentted!
----------------------------
-- Input: 
--     j = number of a red checker
--     r = critical row
--     black = black checkers on the board
isRedCheckerInRegionE = method()
isRedCheckerInRegionE(ZZ,MutableHashTable) := (i,node) -> (
     r := node.CriticalRow;
     black := first node.Board;
     e0 := position(black, b->b==r+1);
     e1 := position(black, b->b==r);
     i < e1 and i >= e0
     )

-----------------------------
-- end Numerical LR-Homotopies
-----------------------------

-------------------
-- Documentation --
-------------------
beginDocumentation()
doc ///
   Key
      NumericalSchubertCalculus
   Headline
      Numerical Schubert Calculus
///
load "NumericalSchubertCalculus/PHCpack-LRhomotopies-doc.m2"
--load "NumericalSchubertCalculus/doc.m2"

-------------------
-- Tests         --
-------------------
TEST ///
load "NumericalSchubertCalculus/TST/4lines.m2"
///
TEST ///
load "NumericalSchubertCalculus/TST/2e4-G26.m2"
///
TEST ///
load "NumericalSchubertCalculus/TST/21e3-G36.m2"
///
end ---------------------------------------------------------------------
-- END OF THE PACKAGE
---------------------------------------------------------------------------
restart
check "NumericalSchubertCalculus"
installPackage "NumericalSchubertCalculus"
installPackage ("NumericalSchubertCalculus", RerunExamples=>true)

