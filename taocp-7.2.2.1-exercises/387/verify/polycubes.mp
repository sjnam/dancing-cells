% Exercise 7.2.2.1-387.  On the left, the polycube answer 387 draws for
% symmetry type (v), "90 degrees": a flat pinwheel of eight cubies, recovered
% from the printed picture.  In the middle, a six-cubie polycube of the same
% type -- the plus pentomino with one cubie on top of its centre.  On the
% right, six cubies of type (vi), "bidiagonal".  Six is the minimum in both
% cases, so the two printed examples are larger than they need to be.

prologues := 3;                 % so that the standalone SVG carries its fonts

u := 15bp;                      % one cubie
color ca, cb;
ca := (.87, .40, .32);
cb := (.42, .60, .84);

% Isometric: x to the lower right, y to the lower left, z straight up, so the
% faces on view are the ones facing +x, +y and +z, and a cubie is nearer the
% eye the larger x+y+z is.
vardef P(expr x, y, z) = (0.866(x-y), z - 0.5(x+y)) * u enddef;

vardef top(expr x, y, z) =
  P(x,y,z+1) -- P(x+1,y,z+1) -- P(x+1,y+1,z+1) -- P(x,y+1,z+1) -- cycle enddef;
vardef rgt(expr x, y, z) =
  P(x+1,y,z) -- P(x+1,y+1,z) -- P(x+1,y+1,z+1) -- P(x+1,y,z+1) -- cycle enddef;
vardef lft(expr x, y, z) =
  P(x,y+1,z) -- P(x+1,y+1,z) -- P(x+1,y+1,z+1) -- P(x,y+1,z+1) -- cycle enddef;

def cubie(expr x, y, z, c, o) =
  fill (top(x,y,z) shifted o) withcolor c;
  fill (rgt(x,y,z) shifted o) withcolor .30[c, black];
  fill (lft(x,y,z) shifted o) withcolor .45[c, white];
  draw (top(x,y,z) shifted o); draw (rgt(x,y,z) shifted o);
  draw (lft(x,y,z) shifted o);
enddef;

% A polycube is given as a list of triples in a string, three digits to a
% cubie; drawing them in order of x+y+z puts the near ones last.
def solid(expr s, c, o) =
  for d = 0 upto 9:
    for i = 0 step 3 until length(s) - 3:
      xx := scantokens(substring (i, i+1) of s);
      yy := scantokens(substring (i+1, i+2) of s);
      zz := scantokens(substring (i+2, i+3) of s);
      if xx + yy + zz = d: cubie(xx, yy, zz, c, o); fi
    endfor
  endfor
enddef;

beginfig(1);
  drawoptions(withpen pencircle scaled .5bp);
  pair o;

  o := (0, 0);
  solid("020" & "100" & "110" & "120" & "210" & "220" & "230" & "310", ca, o);
  label.bot(btex answer 387's type (v): eight cubies etex, o + (0, -68bp));

  o := (150bp, 8bp);
  solid("010" & "100" & "110" & "111" & "120" & "210", cb, o);
  label.bot(btex six of them will do etex, o + (0, -76bp));

  o := (270bp, 8bp);
  solid("010" & "101" & "110" & "111" & "121" & "210", cb, o);
  label.bot(btex and six for type (vi) etex, o + (0, -76bp));
endfig;

end.
