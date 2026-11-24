This is back-reachable-weighted-pruned-partly.ch with the interior costs
of back-reachable-weighted-pruned-intcosts.ch in place of squared weights.
Usage: back-reachable-weighted-pruned-partly-intcosts 37000000 39000000 contiguous-usa-48.gb NY

@x
int count; /* this many regions found */
@y
int count; /* this many regions found */
int rejects; /* but this many were useless */
int tags[1000]; /* I assume that the graph has fewer than 1000 vertices */
@z
@x
  fprintf(stderr,"OK, I've found %d connected sets with weight in [%d..%d).\n",
                        count,pp,qq);
@y
  fprintf(stderr,"OK, I've found %d connected sets with weight in [%d..%d).\n",
                        count,pp,qq);
  if (rejects) fprintf(stderr,"(But I pruned away %d of them, leaving %d.\n",
                                            rejects,count-rejects);
@z
@x
@ @<Process the command line@>=
if (argc!=4 || sscanf(argv[1],"%d",
                         &pp)!=1 || sscanf(argv[2],"%d",
                         &qq)!=1) {
  fprintf(stderr,"Usage: %s P Q foo.gb\n",
                      argv[0]);
  exit(-1);
}
gg=g=restore_graph(argv[3]);
if (!g) {
  fprintf(stderr,"I couldn't reconstruct graph %s!\n",argv[2]);
  exit(-2);
}
if (pp>=qq) {
  fprintf(stderr,"P must be less than Q!\n");
  exit(-2);
}
printf("| %s %d %d %s\n",
             argv[0],pp,qq,argv[3]);
@y
@ @<Process the command line@>=
if (argc!=5 || sscanf(argv[1],"%d",
                         &pp)!=1 || sscanf(argv[2],"%d",
                         &qq)!=1) {
  fprintf(stderr,"Usage: %s P Q foo.gb NY\n",
                      argv[0]);
  exit(-1);
}
gg=g=restore_graph(argv[3]);
if (!g) {
  fprintf(stderr,"I couldn't reconstruct graph %s!\n",argv[2]);
  exit(-2);
}
if (pp>=qq) {
  fprintf(stderr,"P must be less than Q!\n");
  exit(-2);
}
printf("| %s %d %d %s %s\n",
             argv[0],pp,qq,argv[3],argv[4]);
@z
@x
@ @<Record a solution@>=
{
  count++;
  for (k=d=0;k<l;k++) {
    d+=wgt(vrt(k));
    printf(" %s",
                                 vrt(k)->name);
  }
  printf(" |%llu\n",
                 (unsigned long long)d*d);
}
@y
@ @d tag(v) tags[(v)-g->vertices]

@<Record a solution@>=
{
  register Arc *aa;
  register int s;
  count++;
  @<If this solution leaves impossible connected components, set |d| nonzero@>;
  if (d) rejects++;
  else {
    for (k=0;k<l;k++) tag(vrt(k))=count;
    for (s=k=0;k<l;k++) for (aa=vrt(k)->arcs; aa; aa=aa->next)
      if (tag(aa->tip)== count) s++;
    for (k=0;k<l;k++) printf(" %s",
                                   vrt(k)->name);
    printf(" |%d\n",l*(l-1)-s);
  }
}
@z
@x
@*Index.
@y
@ A solution can't be used by {\mc DLX5} if it leaves a connected component
whose size can't be achieved as a sum of other solutions. For example,
if |pp=8| and |qq=12|, we can't use a solution whose residual graph has
a component of weight 23. So we identify the weights of all components
of the complementary graph, and check their validity.

This variant has a prunes more cautiously, because of the way I solved a
problem about US populations, found in the left illustration of
7.2.2.1--(116) in TAOCP Volume 4B: The options in that program include
exceptional cases where the cost does not lie between $P$ and $Q$.
It's a mistake to reject an option based on the weight of such a
component. (Indeed, it was a mistake when I did that in the early
printings of Volume 4B!)

The exceptional options in my application all include a vertex named \.{NY}.
So this program gives a ``whiteball'' when a component of the residual graph
contains a vertex whose name matches the command-line parameter
|argv[4]|.

@d sentinel ((Vertex*)1)
@d dfs u.V /* the one remaining utility field is enough for us */
@d match(v) ((v)->name[0]==argv[4][0] && (v)->name[1]==argv[4][1])

@<If this solution leaves impossible connected components...@>=
d=0;
if (qq>1) {
  for (v=g->vertices;v<g->vertices+g->n;v++) v->dfs=NULL;
  for (k=0;k<l;k++) vrt(k)->dfs=sentinel;
  for (w=g->vertices;d==0 && w<g->vertices+g->n;w++) if (w->dfs==NULL) {
    register Arc *a;
    register int excepted=match(w);
    for (d=wgt(w),w->dfs=sentinel,v=w;v!=sentinel;) {
      for (a=v->arcs,v=v->dfs; a; a=a->next) if (a->tip->dfs==NULL)
        d+=wgt(a->tip), excepted+=match(a->tip), a->tip->dfs=v, v=a->tip;
    }
    k=(d+qq-2)/(qq-1);
    if (d>=k*pp || excepted) d=0;
  }
}

@*Index.
@z
