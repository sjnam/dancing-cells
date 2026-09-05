% The ten convex 56-aboloes that survive O'Beirne's parity test, from answer
% 7.2.2.1-320.  A convex polyabolo is an m by n rectangle with right triangles
% of legs a, b, c, d cut from its four corners, so its outline is read straight
% off the six parameters.  Eight of the ten can be packed by the fourteen
% tetraboloes, and the number of ways is printed underneath; the other two
% cannot, though nothing but a search says so.

prologues := 3;                   % so that the standalone SVG carries its fonts
u    := 6bp;
color good, bad;
good := (.98, .93, .62);
bad  := (.86, .86, .86);

vardef outline(expr m, n, a, b, c, d) =
  (a,0) -- (n-b,0) -- (n,b) -- (n,m-c) -- (n-c,m)
       -- (d,m) -- (0,m-d) -- (0,a) -- cycle
enddef;

% one shape with its two lines of label, placed by the middle of its base
def put(expr m, n, a, b, c, d, cx, cy, col, tag, cnt) =
  begingroup
    save o; pair o;
    o := (cx - .5n*u, cy);
    fill (outline(m,n,a,b,c,d) scaled u shifted o) withcolor col;
    draw (outline(m,n,a,b,c,d) scaled u shifted o) withpen pencircle scaled .5bp;
    label.bot(tag, (cx, cy - 3bp));
    label.bot(cnt, (cx, cy - 16bp));
  endgroup
enddef;

beginfig(1);
  put(5, 7, 3, 2, 0, 1, -150bp, 0, good,
      btex $(5\times7;3,2,0,1)$ etex, btex 5365 etex);
  put(5, 7, 3, 0, 2, 1,  -50bp, 0, good,
      btex $(5\times7;3,0,2,1)$ etex, btex 5274 etex);
  put(5, 7, 3, 1, 0, 2,   50bp, 0, good,
      btex $(5\times7;3,1,0,2)$ etex, btex 4828 etex);
  put(5, 7, 3, 1, 2, 0,  150bp, 0, good,
      btex $(5\times7;3,1,2,0)$ etex, btex 4454 etex);

  put(5, 9, 5, 3, 0, 0, -110bp, -75bp, good,
      btex $(5\times9;5,3,0,0)$ etex, btex 772 etex);
  put(5, 9, 4, 4, 1, 1,    0bp, -75bp, good,
      btex $(5\times9;4,4,1,1)$ etex, btex $2\cdot747$ etex);
  put(7, 7, 5, 1, 4, 0,  110bp, -75bp, good,
      btex $(7\times7;5,1,4,0)$ etex, btex 1836 etex);

  put(3, 11, 2, 2, 1, 1, -55bp, -140bp, good,
      btex $(3\times11;2,2,1,1)$ etex, btex $2\cdot236$ etex);
  put(3, 11, 3, 1, 0, 0,  55bp, -140bp, bad,
      btex $(3\times11;3,1,0,0)$ etex, btex none etex);

  put(1, 29, 1, 1, 0, 0, 0bp, -185bp, bad,
      btex $(1\times29;1,1,0,0)$ etex, btex none etex);
endfig;
