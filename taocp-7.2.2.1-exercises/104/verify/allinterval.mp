% The amazing 12-tone row of exercise 7.2.2.1-104, drawn on the twelve pitch
% classes: 0 1 4 2 9 5 11 3 8 10 7 6, the table of indices to the base 2
% modulo 13.  The eleven steps of the path are eleven different intervals,
% which is the all-interval property that part (a) proves.
%
% This file is read twice: luamplib runs it while verify.w is typeset, and
% mpost runs it on its own to make the picture that README.md shows.

beginfig(1);
  numeric r, k; r := 78bp;
  pair c[];
  numeric row[];
  defaultfont := "cmr8"; defaultscale := 1;

  % pitch class k sits where the hour k would, with 0 at the top
  for k=0 upto 11: c[k] := r*dir(90 - 30k); endfor

  row[0]:=0; row[1]:=1; row[2]:=4; row[3]:=2; row[4]:=9; row[5]:=5;
  row[6]:=11; row[7]:=3; row[8]:=8; row[9]:=10; row[10]:=7; row[11]:=6;

  % the faint circle the classes sit on
  draw fullcircle scaled 2r withpen pencircle scaled .4bp withcolor .75white;

  % the row, read as a path from one class to the next
  for k=0 upto 10:
    draw c[row[k]] -- c[row[k+1]] withpen pencircle scaled 1bp;
  endfor

  % the classes themselves, and their names outside the circle
  for k=0 upto 11:
    fill fullcircle scaled 5bp shifted c[k] withcolor white;
    draw fullcircle scaled 5bp shifted c[k] withpen pencircle scaled .5bp;
    label(decimal(k), 1.18r*dir(90 - 30k));
  endfor

  % the row runs from class 0 to class 6, which answer 103(a) says it must
  fill fullcircle scaled 5bp shifted c[0];
  fill fullcircle scaled 5bp shifted c[6];
endfig;
