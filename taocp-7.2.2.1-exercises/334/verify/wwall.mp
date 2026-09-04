% The false front of exercise 7.2.2.1-334, drawn twice: from the front, where
% it cannot be told from the W-wall of Fig. 75, and from behind and below,
% where the two extra cubies give it away.  Both views use the book's own skew
% projection
%
%       (x,y,z) -> (30x - 42y, 14x + 10y + 45z) u,
%
% whose line of sight is (315,225,-148).  Within a board this small no two
% cubies land on the same spot, so a picture settles exactly which cubies show.
% The lists below run farthest first, and plain overpainting does the rest.

color lit, dark, pale;
u    := 0.42bp;                   % small enough for the text block
lit  := (.97, .90, .58);        % a face turned towards the light
dark := (.60, .49, .08);        % one turned away
pale := white;

vardef P(expr x, y, z) = (30x - 42y, 14x + 10y + 45z) * u enddef;

% one face of a cubie: its least corner, two edge steps, and a colour
def face(expr x, y, z, ax, ay, az, bx, by, bz, c) =
  fill P(x,y,z) -- P(x+ax,y+ay,z+az) -- P(x+ax+bx,y+ay+by,z+az+bz)
       -- P(x+bx,y+by,z+bz) -- cycle withcolor c;
  draw P(x,y,z) -- P(x+ax,y+ay,z+az) -- P(x+ax+bx,y+ay+by,z+az+bz)
       -- P(x+bx,y+by,z+bz) -- cycle withpen pencircle scaled .55bp;
enddef;

% the three faces a viewer in front sees: the top and the -x and -y sides
def frontcube(expr x, y, z) =
  face(x,y,z+1, 1,0,0, 0,1,0, lit);
  face(x,y,z,   0,1,0, 0,0,1, pale);
  face(x,y,z,   1,0,0, 0,0,1, dark);
enddef;

% and the three seen from behind and below: the bottom and the +x and +y sides
def backcube(expr x, y, z) =
  face(x,y,z,   1,0,0, 0,1,0, lit);
  face(x+1,y,z, 0,1,0, 0,0,1, pale);
  face(x,y+1,z, 1,0,0, 0,0,1, dark);
enddef;

beginfig(1);
picture front, back;
front := image(
  frontcube(5,1,1); frontcube(2,5,1); frontcube(5,1,2); frontcube(5,1,3); frontcube(4,1,1); frontcube(1,5,1); frontcube(3,2,1); frontcube(2,4,2); frontcube(4,1,2);
  frontcube(3,3,3); frontcube(2,3,1); frontcube(1,5,2); frontcube(3,2,2); frontcube(1,4,1); frontcube(4,1,3); frontcube(3,1,1); frontcube(2,3,2); frontcube(1,5,3);
  frontcube(3,2,3); frontcube(1,4,2); frontcube(3,1,2); frontcube(2,3,3); frontcube(1,3,1); frontcube(1,4,3); frontcube(3,1,3); frontcube(1,3,2); frontcube(1,3,3););
back := image(
  backcube(1,3,3); backcube(1,3,2); backcube(3,1,3); backcube(1,4,3); backcube(1,3,1); backcube(2,3,3); backcube(3,1,2); backcube(1,4,2); backcube(3,2,3);
  backcube(1,5,3); backcube(2,3,2); backcube(3,1,1); backcube(4,1,3); backcube(1,4,1); backcube(3,2,2); backcube(1,5,2); backcube(2,3,1); backcube(3,3,3);
  backcube(4,1,2); backcube(2,4,2); backcube(3,2,1); backcube(1,5,1); backcube(4,1,1); backcube(5,1,3); backcube(5,1,2); backcube(2,5,1); backcube(5,1,1););

gap := 16bp;
pair d;  d := (xpart urcorner front + gap - xpart llcorner back, 0);
draw front;
draw back shifted d;

defaultfont := "cmr10";
defaultscale := .8;
label.bot(btex from the front etex,
  (.5[xpart llcorner front, xpart urcorner front], ypart llcorner front - 9bp));
label.bot(btex from behind and below etex,
  (.5[xpart llcorner back, xpart urcorner back] + xpart d,
   ypart llcorner back + ypart d - 9bp));
endfig;
