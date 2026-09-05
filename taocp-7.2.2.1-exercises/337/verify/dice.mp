% The two spot patterns of exercise 7.2.2.1-337, drawn from the corner where
% the 1, the 2 and the 3 meet -- the corner that decides a die's handedness.
% The cube runs from 0 to 6 in the even/odd coordinates of exercise 145, and
% the three sides on view are x=0, y=0 and z=0, which carry the 3, the 2 and
% the 1.  Red shows 1, 2, 3 running clockwise and green counterclockwise, so
% one of them is left-handed and the other right-handed, whichever way round
% the reader's convention has it.

prologues := 3;                 % so that the standalone SVG carries its fonts
u    := 7bp;
color rd, gn, ink;
rd  := (.85, .10, .10);
gn  := (.55, .85, .55);
ink := (0, 0, 0);

vardef P(expr x, y, z) = (0.866(x-y), 0.5(x+y) - z) * u enddef;

% an ellipse of radius r in the plane spanned by ea and eb
vardef ell(expr c, ea, eb, r) =
  for i=0 upto 23: (c + r*cosd(15i)*ea + r*sind(15i)*eb) .. endfor cycle
enddef;

def grid(expr o) =
  % the three sides on view, each with its nine cells
  for k = 0, 2, 4, 6:
    draw (P(0,k,0) -- P(0,k,6)) shifted o;
    draw (P(0,0,k) -- P(0,6,k)) shifted o;
    draw (P(k,0,0) -- P(k,0,6)) shifted o;
    draw (P(0,0,k) -- P(6,0,k)) shifted o;
    draw (P(k,0,0) -- P(k,6,0)) shifted o;
    draw (P(0,k,0) -- P(6,k,0)) shifted o;
  endfor
enddef;

% a spot on the side whose fixed coordinate is zero
def spotx(expr y, z, c, o) =
  fill (ell(P(0,y,z), P(0,1,0)-P(0,0,0), P(0,0,1)-P(0,0,0), .62) shifted o)
       withcolor c;
  draw (ell(P(0,y,z), P(0,1,0)-P(0,0,0), P(0,0,1)-P(0,0,0), .62) shifted o)
       withcolor ink withpen pencircle scaled .3bp;
enddef;
def spoty(expr x, z, c, o) =
  fill (ell(P(x,0,z), P(1,0,0)-P(0,0,0), P(0,0,1)-P(0,0,0), .62) shifted o)
       withcolor c;
  draw (ell(P(x,0,z), P(1,0,0)-P(0,0,0), P(0,0,1)-P(0,0,0), .62) shifted o)
       withcolor ink withpen pencircle scaled .3bp;
enddef;
def spotz(expr x, y, c, o) =
  fill (ell(P(x,y,0), P(1,0,0)-P(0,0,0), P(0,1,0)-P(0,0,0), .62) shifted o)
       withcolor c;
  draw (ell(P(x,y,0), P(1,0,0)-P(0,0,0), P(0,1,0)-P(0,0,0), .62) shifted o)
       withcolor ink withpen pencircle scaled .3bp;
enddef;

beginfig(1);
  pair a, b;
  a := (-70bp, 0);
  b := ( 70bp, 0);

  drawoptions(withpen pencircle scaled .4bp);

  % the red die: 3 on the x=0 side, 2 on y=0, 1 on z=0
  grid(a);
  spotx(1, 5, rd, a); spotx(3, 3, rd, a); spotx(5, 1, rd, a);
  spoty(1, 5, rd, a); spoty(5, 1, rd, a);
  spotz(3, 3, rd, a);

  % the green die: the same with the 2 and the 3 exchanged
  grid(b);
  spotx(1, 5, gn, b); spotx(5, 1, gn, b);
  spoty(1, 5, gn, b); spoty(3, 3, gn, b); spoty(5, 1, gn, b);
  spotz(3, 3, gn, b);

  drawoptions();
  label.top(btex red etex, a + (0, 44bp));
  label.top(btex green etex, b + (0, 44bp));
endfig;
