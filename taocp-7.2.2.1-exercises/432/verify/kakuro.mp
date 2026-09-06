% Exercise 7.2.2.1-432.  The two generic diagrams the exercise asks about, with
% their clues named as answer 432 names them, and then the repaired form of the
% puzzle that answer calls the hardest, with its solution.  A clue cell is
% black with a diagonal: the sum of the block running right goes above the
% diagonal, the sum of the block running down below it.

prologues := 3;                 % so that the standalone SVG carries its fonts

u := 26bp;                      % one cell
color blk;
blk := (.13, .13, .13);

vardef tp(expr s) = s infont defaultfont scaled .95 enddef;

vardef at(expr r, c, o) = o + (c*u, -r*u) enddef;
vardef box(expr r, c, o) =
  at(r,c,o) -- at(r,c+1,o) -- at(r+1,c+1,o) -- at(r+1,c,o) -- cycle enddef;

def blank(expr r, c, o) =
  fill box(r,c,o) withcolor blk;  draw box(r,c,o);
enddef;

def openCell(expr r, c, o, p) =
  fill box(r,c,o) withcolor white;  draw box(r,c,o);
  label(p, at(r,c,o) + (.5u,-.5u));
enddef;

% a and d are the sums of the blocks running right and down; pass nullpicture
% where there is no such block.
def clue(expr r, c, o, a, d) =
  fill box(r,c,o) withcolor blk;  draw box(r,c,o);
  draw at(r,c,o) -- at(r+1,c+1,o) withcolor white;
  label.lft(a, at(r,c+1,o) + (-.05u,-.27u)) withcolor white;
  label.rt(d, at(r+1,c,o) + (.05u,.27u)) withcolor white;
enddef;

% Shape (a): blocks of 2, 3, 2 running right and 2, 3, 2 running down.  The
% nine pictures are the three across sums, the three down sums, and the seven
% cells, all handed in as arrays.
picture ss[], tt[], ee[];
def shapea(expr o) =
  blank(0,0,o);
  clue(0,1,o,nullpicture,tt1);  clue(0,2,o,nullpicture,tt2);  blank(0,3,o);
  clue(1,0,o,ss1,nullpicture);  openCell(1,1,o,ee1);  openCell(1,2,o,ee2);
  clue(1,3,o,nullpicture,tt3);
  clue(2,0,o,ss2,nullpicture);  openCell(2,1,o,ee3);  openCell(2,2,o,ee4);
  openCell(2,3,o,ee5);
  blank(3,0,o);  clue(3,1,o,ss3,nullpicture);
  openCell(3,2,o,ee6);  openCell(3,3,o,ee7);
enddef;

def shapeb(expr o) =
  blank(0,0,o);
  clue(0,1,o,nullpicture,tt1);  clue(0,2,o,nullpicture,tt2);
  clue(0,3,o,nullpicture,tt3);
  clue(1,0,o,ss1,nullpicture);
  clue(2,0,o,ss2,nullpicture);
  clue(3,0,o,ss3,nullpicture);
  for r = 1 upto 3: for c = 1 upto 3: openCell(r,c,o,nullpicture); endfor endfor
enddef;

def noDigits =
  for i = 1 upto 7: ee[i] := nullpicture; endfor
enddef;

beginfig(1);
  drawoptions(withpen pencircle scaled .5bp);
  pair o;

  ss1 := btex $s_1$ etex;  ss2 := btex $s_2$ etex;  ss3 := btex $s_3$ etex;
  tt1 := btex $t_1$ etex;  tt2 := btex $t_2$ etex;  tt3 := btex $t_3$ etex;
  noDigits;
  o := (0, 0);            shapea(o);
  label.bot(btex (a) etex, o + (2u, -4u - 8bp));
  o := (150bp, 0);        shapeb(o);
  label.bot(btex (b) etex, o + (2u, -4u - 8bp));

  ss1 := tp("6");  ss2 := tp("19"); ss3 := tp("6");
  tt1 := tp("8");  tt2 := tp("13"); tt3 := tp("10");
  ee1 := tp("5");  ee2 := tp("1");  ee3 := tp("3");  ee4 := tp("7");
  ee5 := tp("9");  ee6 := tp("5");  ee7 := tp("1");
  o := (300bp, 0);        shapea(o);
  label.bot(btex $6\,19\,6/8\,13\,10$ etex, o + (2u, -4u - 8bp));
endfig;

end.
