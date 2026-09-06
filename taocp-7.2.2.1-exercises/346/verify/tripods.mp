% Exercise 7.2.2.1-346.  On the left, the (2,2,2)-tripod: a corner cubie with
% three legs of two cubies each.  On the right, the three layers of the packing
% that fills 7/9 of space with period 3 -- the tripods whose corners run down
% the main diagonal of the 3x3x3 torus.  A cubie belongs to tripod p exactly
% when p occurs at least twice among its three coordinates, so the six cubies
% whose coordinates are all different are the ones left over.

prologues := 3;                 % so that the standalone SVG carries its fonts

u    := 15bp;                   % one cubie, isometric
v    := 15bp;                   % one cell of a layer diagram
color ca, cb, cc, ink, pale;
ca   := (.87, .40, .32);
cb   := (.42, .60, .84);
cc   := (.95, .80, .35);
ink  := (0, 0, 0);
pale := (.93, .93, .93);

% The isometric projection.  The x axis runs to the lower right, y to the lower
% left, z straight up, so the three faces on view are the ones facing +x, +y
% and +z, and a cubie is nearer the eye the larger x+y+z is.
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

% One 3x3 layer of the packing, with rows y = 0,1,2 downward and columns
% z = 0,1,2 rightward.  The string s gives the owner of each cell, a dot where
% no tripod reaches.
def layer(expr s, o) =
  for i = 0 upto 2: for j = 0 upto 2:
    fill (unitsquare xscaled v yscaled v shifted ((j*v, -(i+1)*v)) shifted o)
      withcolor if substring (3i+j, 3i+j+1) of s = "0": ca
                elseif substring (3i+j, 3i+j+1) of s = "1": cb
                elseif substring (3i+j, 3i+j+1) of s = "2": cc
                else: pale fi;
  endfor endfor
  for k = 0 upto 3:
    draw ((k*v, 0) -- (k*v, -3v)) shifted o;
    draw ((0, -k*v) -- (3v, -k*v)) shifted o;
  endfor
enddef;

beginfig(1);
  drawoptions(withpen pencircle scaled .5bp);
  pair o; o := (0, 0);

  % The pod at (2,2,2): its legs run back towards the coordinate planes.
  % Cubies nearer the eye have the larger x+y+z, so draw them last.
  for s = 4 upto 6:
    for i = 0 upto 1: if i+4 = s: cubie(i, 2, 2, ca, o); fi endfor
    for j = 0 upto 1: if j+4 = s: cubie(2, j, 2, ca, o); fi endfor
    for k = 0 upto 1: if k+4 = s: cubie(2, 2, k, ca, o); fi endfor
    if s = 6: cubie(2, 2, 2, ca, o); fi
  endfor
  label.bot(btex the $(2,2,2)$-tripod etex, (0, -72bp));

  % The three layers of the period-3 packing.
  o := (150bp, 2bp);
  layer("000" & "01." & "0.2", o);
  label.bot(btex $x=0$ etex, o + (1.5v, -3v - 4bp));
  o := o + (3.9v, 0);
  layer("01." & "111" & ".12", o);
  label.bot(btex $x=1$ etex, o + (1.5v, -3v - 4bp));
  o := o + (3.9v, 0);
  layer("0.2" & ".12" & "222", o);
  label.bot(btex $x=2$ etex, o + (1.5v, -3v - 4bp));
  label.bot(btex three of them fill $21$ of the $27$ cubies etex,
            (150bp + 5.4v, -72bp));
endfig;

end.
