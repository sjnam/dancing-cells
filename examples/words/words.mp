% words.mp -- figure for words.w
% Build with: mptopdf words.mp   (-> words-1.pdf)
% One solution seen as an exact cover of the 26 letter items:
%   squab glitz nymph frock vowed, sharing o and giving up j and x.

verbatimtex
\documentclass{article}
\usepackage{kotex}
\begin{document}
etex

defaultfont := "cmtt10";
defaultscale := 1.2;

beginfig(1);
  numeric w, h, gap, xa, xb;
  w := 14; h := 17; gap := 13;
  string s[]; picture lb[]; numeric tint[], dsh[];

  s1 := "squab"; lb1 := btex \texttt{squab} etex;         tint1 := 1;    dsh1 := 0;
  s2 := "glitz"; lb2 := btex \texttt{glitz} etex;         tint2 := 1;    dsh2 := 0;
  s3 := "nymph"; lb3 := btex \texttt{nymph} etex;         tint3 := 1;    dsh3 := 0;
  s4 := "frck";  lb4 := btex \texttt{frock} etex;          tint4 := 0.87; dsh4 := 0;
  s5 := "vwed";  lb5 := btex \texttt{vowed} etex;          tint5 := 0.87; dsh5 := 0;
  s6 := "o";     lb6 := btex 겹침 etex;                  tint6 := 0.68; dsh6 := 0;
  s7 := "jx";    lb7 := btex 빠짐 etex;                    tint7 := 1;    dsh7 := 1;

  xa := 0;
  for i = 1 upto 7:
    xb := xa;
    for j = 1 upto length(s[i]):
      fill unitsquare xscaled w yscaled h shifted (xa, 0) withcolor tint[i]*white;
      if dsh[i] = 1:
        draw unitsquare xscaled w yscaled h shifted (xa, 0) dashed evenly;
      else:
        draw unitsquare xscaled w yscaled h shifted (xa, 0);
      fi
      label(substring (j-1, j) of s[i], (xa + w/2, h/2));
      xa := xa + w;
    endfor
    draw (xb, -4) -- (xb, -7) -- (xa, -7) -- (xa, -4);
    label.bot(lb[i], ((xb + xa)/2, -8));
    xa := xa + gap;
  endfor
endfig;

end
