% The ten tetraskews of exercise 7.2.2.1-323, drawn with the skewed grid of
% answer 323(a): the vertex (m,n) of the square grid moves to
%
%       (m - e[n odd], n - e[m odd]),
%
% so a cell is a square when m+n is odd and a rhombus when it is even.  The
% skew e is exaggerated here, to 0.22, so that the two kinds can be told apart;
% the leans of the rhombuses and the spins of the squares are then plain, and
% so is the checkerboard.

prologues := 3;                 % so that the standalone SVG carries its fonts
u   := 13bp;
eps := 0.22;
color sq, rh;
sq := (.98, .93, .62);          % a square
rh := (.55, .60, .78);          % a rhombus

vardef V(expr m, n) =
  ((m - if odd n: eps else: 0 fi), (n - if odd m: eps else: 0 fi)) * u
enddef;

vardef cellpath(expr m, n) =
  V(m,n) -- V(m+1,n) -- V(m+1,n+1) -- V(m,n+1) -- cycle
enddef;

def drawcell(expr m, n, o) =
  fill (cellpath(m,n) shifted o)
       withcolor if odd (m+n): sq else: rh fi;
  draw (cellpath(m,n) shifted o) withpen pencircle scaled .5bp;
enddef;

beginfig(1);
  % straight
  drawcell(0, 0, (0.00u, 0.00u));
  drawcell(1, 0, (0.00u, 0.00u));
  drawcell(2, 0, (0.00u, 0.00u));
  drawcell(3, 0, (0.00u, 0.00u));
  label.bot(btex straight etex, (2.00u, -0.35u));
  % ell
  drawcell(1, 0, (4.50u, 0.00u));
  drawcell(2, 0, (4.50u, 0.00u));
  drawcell(3, 0, (4.50u, 0.00u));
  drawcell(1, 1, (4.50u, 0.00u));
  label.bot(btex ell etex, (7.00u, -0.35u));
  % ell
  drawcell(1, 1, (9.50u, -1.00u));
  drawcell(1, 2, (9.50u, -1.00u));
  drawcell(2, 2, (9.50u, -1.00u));
  drawcell(3, 2, (9.50u, -1.00u));
  label.bot(btex ell etex, (12.00u, -0.35u));
  % tee
  drawcell(1, 0, (14.50u, 0.00u));
  drawcell(2, 0, (14.50u, 0.00u));
  drawcell(3, 0, (14.50u, 0.00u));
  drawcell(2, 1, (14.50u, 0.00u));
  label.bot(btex tee etex, (17.00u, -0.35u));
  % ell
  drawcell(0, 0, (20.50u, 0.00u));
  drawcell(1, 0, (20.50u, 0.00u));
  drawcell(2, 0, (20.50u, 0.00u));
  drawcell(0, 1, (20.50u, 0.00u));
  label.bot(btex ell etex, (22.00u, -0.35u));
  % square
  drawcell(0, 0, (1.00u, -4.60u));
  drawcell(1, 0, (1.00u, -4.60u));
  drawcell(0, 1, (1.00u, -4.60u));
  drawcell(1, 1, (1.00u, -4.60u));
  label.bot(btex square etex, (2.00u, -4.95u));
  % skew
  drawcell(1, 1, (6.00u, -5.60u));
  drawcell(0, 2, (6.00u, -5.60u));
  drawcell(1, 2, (6.00u, -5.60u));
  drawcell(0, 3, (6.00u, -5.60u));
  label.bot(btex skew etex, (7.00u, -4.95u));
  % skew
  drawcell(1, 1, (9.50u, -5.60u));
  drawcell(2, 1, (9.50u, -5.60u));
  drawcell(2, 2, (9.50u, -5.60u));
  drawcell(3, 2, (9.50u, -5.60u));
  label.bot(btex skew etex, (12.00u, -4.95u));
  % ell
  drawcell(0, 0, (16.00u, -4.60u));
  drawcell(0, 1, (16.00u, -4.60u));
  drawcell(0, 2, (16.00u, -4.60u));
  drawcell(1, 2, (16.00u, -4.60u));
  label.bot(btex ell etex, (17.00u, -4.95u));
  % tee
  drawcell(0, 0, (20.50u, -4.60u));
  drawcell(1, 0, (20.50u, -4.60u));
  drawcell(2, 0, (20.50u, -4.60u));
  drawcell(1, 1, (20.50u, -4.60u));
  label.bot(btex tee etex, (22.00u, -4.95u));
endfig;
