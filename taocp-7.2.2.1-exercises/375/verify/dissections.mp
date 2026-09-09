% Exercise 7.2.2.1-375.  The four extreme incomparable dissections.
%
% Upper left:  the unique 13 x 22 rectangle, semiperimeter 35, seven pieces.
% Upper right: the unique 34 x 34 square, seven pieces.
% Lower left:  the smallest square with eight pieces, 27 x 27.
% Lower right: the 30 x 17 rectangle of the fourth diagram of answer 375(b),
%              semiperimeter 47 where the answer says 56.
%
% The number in each piece is its label: widths increase and heights fall as
% the label grows.

prologues := 3;                 % so that the standalone SVG carries its fonts

defaultfont := "cmr10";
defaultscale := .55;

color dim;
dim := (.45, .45, .45);

numeric s;                      % the scale of the panel being drawn
pair o;                         % its top left corner

def piece(expr xa, xb, ya, yb, lab) =
  begingroup
    save p, c; path p; pair c;
    p := (o + (xa*s, -ya*s)) -- (o + (xb*s, -ya*s))
      -- (o + (xb*s, -yb*s)) -- (o + (xa*s, -yb*s)) -- cycle;
    fill p withcolor (.93, .93, .93);
    draw p withpen pencircle scaled .4bp;
    c := o + (.5(xa+xb)*s, -.5(ya+yb)*s);
    label(lab, c);
  endgroup
enddef;

numeric capy;                   % where the captions of this row sit

def caption(expr wide, txt) =
  label.bot(txt, (xpart o + .5*wide*s, capy));
enddef;

beginfig(1);
  % ---- the unique rectangle of semiperimeter 35, with seven pieces
  capy := -158bp;
  s := 6.5; o := (0, 0);
  piece(0, 2, 0, 16, "2");
  piece(2, 13, 0, 4, "7");
  piece(2, 12, 4, 9, "6");
  piece(12, 13, 4, 22, "1");
  piece(2, 9, 9, 16, "4");
  piece(9, 12, 9, 22, "3");
  piece(0, 9, 16, 22, "5");
  caption(13, btex $13\times22$, seven pieces etex);

  % ---- the unique square of side 34, with seven pieces
  s := 4.4; o := (205bp, 0);
  piece(0, 7, 0, 25, "2");
  piece(7, 34, 0, 6, "7");
  piece(7, 31, 6, 14, "6");
  piece(31, 34, 6, 34, "1");
  piece(7, 21, 14, 25, "4");
  piece(21, 31, 14, 34, "3");
  piece(0, 21, 25, 34, "5");
  caption(34, btex $34\times34$, seven pieces etex);

  % ---- the smallest square with eight pieces
  capy := -373bp;
  s := 5.4; o := (0, -215bp);
  piece(0, 5, 0, 19, "3");
  piece(5, 26, 0, 4, "8");
  piece(26, 27, 0, 27, "1");
  piece(5, 23, 4, 10, "7");
  piece(23, 26, 4, 27, "2");
  piece(5, 16, 10, 19, "5");
  piece(16, 23, 10, 27, "4");
  piece(0, 16, 19, 27, "6");
  caption(27, btex $27\times27$, eight pieces etex);

  % ---- the fourth diagram of answer 375(b), at semiperimeter 47
  s := 4.9; o := (205bp, -215bp);
  piece(0, 4, 0, 16, "1");
  piece(4, 21, 0, 3, "7");
  piece(21, 30, 0, 9, "3");
  piece(4, 9, 3, 16, "2");
  piece(9, 21, 3, 9, "6");
  piece(9, 20, 9, 16, "5");
  piece(20, 30, 9, 17, "4");
  piece(0, 20, 16, 17, "8");
  caption(30, btex $30\times17$, eight pieces etex);
endfig;

end.
