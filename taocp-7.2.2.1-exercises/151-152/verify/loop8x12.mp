% The 8x12 array of exercise 7.2.2.1-152: all forty-eight path dominoes, their
% arcs forming a single closed loop.  Found by verify.w, chunk 4.
%
% This file is read twice: luamplib runs it while verify.w is typeset, and
% mpost runs it on its own to make the picture that README.md shows.

beginfig(1);
  numeric s, R, C, hw; s := 37bp; R := 8; C := 12; hw := .059s;
  pair p[], q[]; path crv[], rct[]; numeric na, nr, k;
  color band; band := .88white;

  % One domino: its six attachment points, the inward normal at each, and its
  % outline.  A horizontal tile is read left, top-left, top-right, right,
  % bottom-right, bottom-left; a vertical one top, right-top, right-bottom,
  % bottom, left-bottom, left-top.
  def dom(expr o, r, c) =
    if o = 0:
      p[0] := (c*s, (R-r-.5)*s);      q[0] := right;
      p[1] := ((c+.5)*s, (R-r)*s);    q[1] := down;
      p[2] := ((c+1.5)*s, (R-r)*s);   q[2] := down;
      p[3] := ((c+2)*s, (R-r-.5)*s);  q[3] := left;
      p[4] := ((c+1.5)*s, (R-r-1)*s); q[4] := up;
      p[5] := ((c+.5)*s, (R-r-1)*s);  q[5] := up;
      nr := nr + 1;
      rct[nr] := (c*s,(R-r-1)*s)--((c+2)*s,(R-r-1)*s)--((c+2)*s,(R-r)*s)
        --(c*s,(R-r)*s)--cycle;
    else:
      p[0] := ((c+.5)*s, (R-r)*s);    q[0] := down;
      p[1] := ((c+1)*s, (R-r-.5)*s);  q[1] := left;
      p[2] := ((c+1)*s, (R-r-1.5)*s); q[2] := left;
      p[3] := ((c+.5)*s, (R-r-2)*s);  q[3] := up;
      p[4] := (c*s, (R-r-1.5)*s);     q[4] := right;
      p[5] := (c*s, (R-r-.5)*s);      q[5] := right;
      nr := nr + 1;
      rct[nr] := (c*s,(R-r-2)*s)--((c+1)*s,(R-r-2)*s)--((c+1)*s,(R-r)*s)
        --(c*s,(R-r)*s)--cycle;
    fi
  enddef;

  % An arc leaves one attachment point along the inward normal and arrives at
  % another along the outward one, which is what makes neighbouring tiles join
  % smoothly across a domino edge.
  def arc(expr a, b) =
    na := na + 1; crv[na] := p[a]{q[a]} .. {-q[b]}p[b];
  enddef;

  % One edge of the road: the arc offset along its normal.  Sampling with the
  % tangent named at every sample keeps the offset as smooth as the arc.
  path edge, edgeL;
  def side(expr a, w) =
    edge := ((point 0 of a)
             shifted (w*(unitvector(direction 0 of a) rotated 90)))
              {direction 0 of a}
      .. ((point .25 of a)
          shifted (w*(unitvector(direction .25 of a) rotated 90)))
           {direction .25 of a}
      .. ((point .5 of a)
          shifted (w*(unitvector(direction .5 of a) rotated 90)))
           {direction .5 of a}
      .. ((point .75 of a)
          shifted (w*(unitvector(direction .75 of a) rotated 90)))
           {direction .75 of a}
      .. ((point 1 of a)
          shifted (w*(unitvector(direction 1 of a) rotated 90)))
           {direction 1 of a};
  enddef;

  na := 0; nr := 0;
  dom(0,0,4);
  dom(0,0,0); arc(3,4);
  dom(0,0,10); arc(0,4);
  dom(0,7,0); arc(2,3);
  dom(0,7,10); arc(0,2);
  dom(1,0,3); arc(2,3); arc(4,5);
  dom(1,0,2); arc(1,3); arc(2,5);
  dom(0,1,0); arc(2,4);
  dom(0,2,0); arc(2,4); arc(3,5);
  dom(0,6,0); arc(1,2); arc(3,4);
  dom(0,0,6); arc(4,5);
  dom(1,0,8); arc(1,3); arc(2,4);
  dom(1,0,9); arc(1,3); arc(4,5);
  dom(0,1,10); arc(2,5);
  dom(0,2,10); arc(0,5); arc(1,4);
  dom(0,3,0); arc(1,2); arc(3,5);
  dom(0,4,0); arc(1,4); arc(3,5);
  dom(0,5,0); arc(1,4); arc(2,5);
  dom(0,6,10); arc(1,4);
  dom(0,5,10); arc(0,1); arc(2,5);
  dom(1,6,9); arc(0,5); arc(2,4);
  dom(1,3,11); arc(0,3); arc(4,5);
  dom(0,7,2); arc(0,3);
  dom(1,5,2); arc(0,1); arc(2,4);
  dom(1,1,4); arc(1,2); arc(4,5);
  dom(0,7,4); arc(0,1); arc(2,3);
  dom(1,6,6); arc(1,5); arc(2,4);
  dom(0,7,7); arc(0,2); arc(1,3);
  dom(0,1,5); arc(0,2); arc(3,4);
  dom(1,1,7); arc(0,1); arc(2,3); arc(4,5);
  dom(0,2,2); arc(0,2); arc(1,4); arc(3,5);
  dom(0,2,5); arc(0,2); arc(3,5);
  dom(1,3,2); arc(0,1); arc(2,4); arc(3,5);
  dom(0,6,3); arc(0,1); arc(3,4);
  dom(1,5,5); arc(0,1); arc(2,5); arc(3,4);
  dom(0,5,3); arc(0,3); arc(1,5);
  dom(0,5,6); arc(0,3); arc(1,4);
  dom(0,6,7); arc(0,2); arc(1,3); arc(4,5);
  dom(0,3,3); arc(0,4); arc(1,3);
  dom(0,4,3); arc(0,3); arc(2,5);
  dom(1,3,5); arc(0,3); arc(1,2); arc(4,5);
  dom(0,3,6); arc(0,5); arc(2,3);
  dom(0,4,6); arc(0,5); arc(1,3);
  dom(1,2,8); arc(0,3); arc(1,4); arc(2,5);
  dom(1,2,9); arc(0,3); arc(1,5); arc(2,4);
  dom(1,3,10); arc(0,4); arc(1,3); arc(2,5);
  dom(0,4,8); arc(0,4); arc(1,5); arc(2,3);
  dom(0,5,8); arc(0,5); arc(1,4); arc(2,3);

  % Each arc is filled and outlined before the next one is drawn, so that a
  % later strand hides the one it crosses -- the road goes over and under, as
  % it does in the figures of the book.  Drawing the two edges rather than
  % stroking the arc is what keeps the pen from leaving a cap mark where a
  % strand meets a domino edge.
  for k=1 upto na:
    side(crv[k], hw); edgeL := edge; side(crv[k], -hw);
    fill edgeL -- reverse edge -- cycle withcolor band;
    draw edgeL withpen pencircle scaled .95bp;
    draw edge withpen pencircle scaled .95bp;
  endfor
  for k=1 upto nr: draw rct[k] withpen pencircle scaled .5bp; endfor
endfig;
