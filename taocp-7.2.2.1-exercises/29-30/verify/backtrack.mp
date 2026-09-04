% The tree drawn in exercise 7.2.2.1-29, with the columns that answer 29's
% construction gives to each of its nodes.
%
% This file is read twice: luamplib runs it while verify.w is typeset, and
% mpost runs it on its own to make the picture that README.md shows.

beginfig(1);
  numeric u, v; u := 34bp; v := 30bp;
  pair root, sub[], leaf[];
  defaultfont := "cmr8"; defaultscale := 1;

  root := (0, 2v);
  sub[1] := (-1.6u, v);   sub[2] := (1.6u, v);
  for i=1 upto 3: leaf[i] := (-(3.6-i)*u, 0); endfor
  for i=4 upto 6: leaf[i] := ((i-3.4)*u, 0); endfor

  % edges, then nodes on top of them
  draw root -- sub[1];  draw root -- sub[2];
  for i=1 upto 3: draw sub[1] -- leaf[i]; endfor
  for i=4 upto 6: draw sub[2] -- leaf[i]; endfor
  fill fullcircle scaled 3.4bp shifted root;
  for i=1 upto 2: fill fullcircle scaled 3.4bp shifted sub[i]; endfor
  for i=1 upto 6: fill fullcircle scaled 3.4bp shifted leaf[i]; endfor

  % A leaf contributes one column; an interior node contributes three more,
  % which is why the matrix has 3*3 + 6 = 15 of them.
  label.rt("13,14,15", root shifted (7bp,0));
  label.lft("4,5,6", sub[1] shifted (-7bp,0));
  label.rt("10,11,12", sub[2] shifted (7bp,0));
  for i=1 upto 6:
    label.bot(decimal(if i<4: i else: i+3 fi), leaf[i] shifted (0,-3bp));
  endfor
endfig;
