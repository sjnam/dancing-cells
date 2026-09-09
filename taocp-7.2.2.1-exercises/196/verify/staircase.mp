% Exercise 7.2.2.1-196.  Three views of a bounded permutation problem.
%
% Left: the options of a = 246677889 as a 9x9 grid, with the column counts
% underneath; read from the right they are the dual b = 135778899.
% Middle: the item that step X3 of Algorithm X branches on at each depth of
% the search for a = 246677889.
% Right: updates per solution, for the three families of parts (f), (g), (h),
% against the two limits 4e-1 and 12.

prologues := 3;                 % so that the standalone SVG carries its fonts

defaultfont := "cmr10";
defaultscale := .7;

color ink, pale, dim;
ink  := (.13, .13, .13);
pale := (.82, .82, .82);
dim  := (.45, .45, .45);

numeric aa[], bb[], cc[];
aa[1] := 2; aa[2] := 4; aa[3] := 6; aa[4] := 6; aa[5] := 7;
aa[6] := 7; aa[7] := 8; aa[8] := 8; aa[9] := 9;
for k = 1 upto 9:
  cc[k] := 0;
  for j = 1 upto 9: if aa[j] >= k: cc[k] := cc[k] + 1; fi endfor
endfor

% ---------------------------------------------------------------- the grid
numeric u;  u := 13bp;

def grid(expr o) =
  begingroup
    save p; path p;
    for j = 1 upto 9:
      for k = 1 upto 9:
        p := unitsquare scaled u shifted (o + ((k-1)*u, -j*u));
        if k <= aa[j]: fill p withcolor pale; fi
        draw p withpen pencircle scaled .3bp withcolor dim;
      endfor
      label.lft(decimal j, o + (-2bp, -(j-.5)*u));
      label.rt(decimal aa[j], o + (9*u + 2bp, -(j-.5)*u));
    endfor
    for k = 1 upto 9:
      label.top(decimal k, o + ((k-.5)*u, 2bp));
      label.bot(decimal cc[k], o + ((k-.5)*u, -9*u - 3bp));
    endfor
  endgroup
enddef;

% ------------------------------------------------------------- the branches
numeric levy;  levy := 26bp;

def spine(expr o) =
  begingroup
    save x, y, w, kids, m;
    numeric x[], w, m;
    pair y[];
    % four levels of branching: 1, 2, 2, 3 children
    x[0] := 0;
    drawdot (o + (0, 0)) withpen pencircle scaled 2.5bp withcolor ink;
    label.lft(btex {\sevenrm depth 0} etex, o + (-88bp, 0));
    label.rt(btex $Y_9$ etex, o + (-82bp, 0));
    draw (o + (0,0)) -- (o + (0, -levy)) withcolor ink;
    drawdot (o + (0, -levy)) withpen pencircle scaled 2.5bp withcolor ink;
    label.lft(btex {\sevenrm depth 1} etex, o + (-88bp, -levy));
    label.rt(btex $X_1$ etex, o + (-82bp, -levy));
    for s = -1, 1:
      draw (o + (0, -levy)) -- (o + (s*36bp, -2*levy)) withcolor ink;
      drawdot (o + (s*36bp, -2*levy)) withpen pencircle scaled 2.5bp
        withcolor ink;
      for t = -1, 1:
        draw (o + (s*36bp, -2*levy)) -- (o + (s*36bp + t*17bp, -3*levy))
          withcolor ink;
        drawdot (o + (s*36bp + t*17bp, -3*levy)) withpen pencircle scaled 2bp
          withcolor ink;
        for r = -1, 0, 1:
          draw (o + (s*36bp + t*17bp, -3*levy))
            -- (o + (s*36bp + t*17bp + r*5.5bp, -3.7*levy)) withcolor dim;
        endfor
      endfor
    endfor
    label.lft(btex {\sevenrm depth 2} etex, o + (-88bp, -2*levy));
    label.rt(btex $Y_8$ etex, o + (-82bp, -2*levy));
    label.lft(btex {\sevenrm depth 3} etex, o + (-88bp, -3*levy));
    label.rt(btex $X_2$ etex, o + (-82bp, -3*levy));
    label.lft(btex {\sevenrm depth 4} etex, o + (-88bp, -3.9*levy));
    label.rt(btex $Y_7$ etex, o + (-82bp, -3.9*levy));
  endgroup
enddef;

% ---------------------------------------------------------------- the plot
numeric ff[], gg[], hh[], wide, high;
ff[1] := 3;        gg[1] := 3;        hh[1] := 3;
ff[2] := 6.5;      gg[2] := 6.5;      hh[2] := 6.5;
ff[3] := 8.666667; gg[3] := 8.75;     hh[3] := 8.75;
ff[4] := 9.541667; gg[4] := 10.125;   hh[4] := 9.583333;
ff[5] := 9.8;      gg[5] := 10.9375;  hh[5] := 9.916667;
ff[6] := 9.859722; gg[6] := 11.40625; hh[6] := 9.909722;
ff[7] := 9.871032; gg[7] := 11.671875; hh[7] := 9.907986;
ff[8] := 9.872842; gg[8] := 11.820312; hh[8] := 9.884375;
ff[9] := 9.873093; gg[9] := 11.902344; hh[9] := 9.879097;
ff[10] := 9.873124; gg[10] := 11.947266; hh[10] := 9.874664;
ff[11] := 9.873127; gg[11] := 11.971680; hh[11] := 9.873848;
ff[12] := 9.873127; gg[12] := 11.984863; hh[12] := 9.873290;
ff[13] := 9.873127; gg[13] := 11.991943; hh[13] := 9.873203;
ff[14] := 9.873127; gg[14] := 11.995728; hh[14] := 9.873143;
ff[15] := 9.873127; gg[15] := 11.997742; hh[15] := 9.873135;
ff[16] := 9.873127; gg[16] := 11.998810; hh[16] := 9.873129;

wide := 150bp;  high := 108bp;

def at(expr o, n, v) = (o + ((n-1)/15*wide, v/13*high)) enddef;

def curve(expr o)(suffix ary) =
  begingroup
    save p; path p;
    p := at(o, 1, ary[1]) for n = 2 upto 16: -- at(o, n, ary[n]) endfor;
    draw p withpen pencircle scaled .8bp withcolor ink;
    for n = 1 upto 16:
      drawdot at(o, n, ary[n]) withpen pencircle scaled 1.6bp withcolor ink;
    endfor
  endgroup
enddef;

def frame(expr o) =
  begingroup
    draw (o + (0, 13/13*high)) -- o -- (o + (wide, 0)) withcolor dim;
    draw at(o, 1, 9.873127) -- at(o, 16, 9.873127) dashed evenly
      withcolor dim;
    draw at(o, 1, 12) -- at(o, 16, 12) dashed evenly withcolor dim;
    label.lft(btex {\sevenrm $4e-1$} etex, at(o, 1, 9.873127) + (-3bp, -3bp));
    label.lft(btex {\sevenrm 12} etex, at(o, 1, 12) + (-3bp, 3bp));
    for n = 1, 4, 8, 12, 16:
      draw at(o, n, 0) -- at(o, n, -.4) withcolor dim;
      label.bot(decimal n, at(o, n, -.6));
    endfor
    label.bot(btex {\sevenrm $n$} etex, (xpart o + wide, ypart o - 14bp));
  endgroup
enddef;

beginfig(1);
  grid((0, 0));
  label.top(btex the options $X_j\,Y_k$, and the column counts etex,
    (58bp, 22bp));
  label.bot(btex read from the right: $b=135778899$ etex, (58bp, -148bp));

  spine((330bp, -14bp));
  label.top(btex the item step X3 branches on etex, (312bp, 22bp));
  label.bot(btex $Y_9$, $X_1$, $Y_8$, $X_2$, \dots\ alternating etex,
    (312bp, -148bp));

  frame((110bp, -310bp));
  curve((110bp, -310bp))(ff);
  curve((110bp, -310bp))(gg);
  curve((110bp, -310bp))(hh);
  label.rt(btex (g) etex, at((110bp, -310bp), 16, gg[16]) + (4bp, 0));
  label.rt(btex (f), (h) etex, at((110bp, -310bp), 16, ff[16]) + (4bp, 0));
  label.top(btex updates per solution etex, (165bp, -180bp));
  label.bot(btex $4e-1$ for (f) and (h), 12 for (g) etex, (165bp, -336bp));
endfig;

end.
