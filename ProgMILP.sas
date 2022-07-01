/************************ CREATION DE LA BASE DE DONNEES ****************************/

/* Definition des parametres initiaux */
%let NbreClients = 25;
%let NbreUsines = 10;
%let CapaciteUsine = 40;
%let DemandeMax = 10;
%let xmax = 200;
%let ymax = 100;
%let seed = 900;

/* Creation des donnees aleatoires de localisation et de demande des clients*/
data data cdata(drop=i);
length NomClient $8;
do i = 1 to &NbreClients;
NomClient = compress('C'||put(i,best.));
x = ranuni(&seed) * &xmax;
y = ranuni(&seed) * &ymax;
demande = ranuni(&seed) * &DemandeMax;
output;
end;
run;

proc print data = cdata;
run;

/* Creation des donnees aleatoires de localisation des usines et des couts de construction */
data udata(drop=i);
length NomUsine $8;
do i = 1 to &NbreUsines;
NomUsine = compress('U'||put(i,best.));
x = ranuni(&seed) * &xmax;
y = ranuni(&seed) * &ymax;
CoutUsine = 30 * (abs(&xmax/2-x) + abs(&ymax/2-y));
output;
end;
run;

proc print data = udata;
run;


/************************ RESOLUTION DU PROBLEME ****************************/

proc optmodel;
set <str> Clients;
set <str> Usines init {};

/* x et y coordonnees de Clients and Usines */
num x {Clients union Usines};
num y {Clients union Usines};
num demande {Clients};
num CoutUsine {Usines};

/* Distance du client i par rapport a l'usine j */
num dist {i in Clients, j in Usines}
= sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2);
read data cdata into Clients=[NomClient] x y demande;
read data udata into Usines=[NomUsine] x y CoutUsine;
var Affecter {Clients, Usines} binary;
var Construire {Usines} binary;

/* Definition de la fonction objectif */
min Z = sum {i in Clients, j in Usines} dist[i,j] * Affecter[i,j] + sum {j in Usines} CoutUsine[j] * Construire[j];

/* Contrainte 1 : Chaque client est affecte a exactement une usine */
con affecter_def {i in Clients}:
sum {j in Usines} Affecter[i,j] = 1;

/* Contrainte 2 : Si le client i est affecte a l'usine j, alors cette usine doit etre construite necessairement */
con lien {i in Clients, j in Usines}:
Affecter[i,j] <= Construire[j];

/* Contrainte 3 : Respect des capacites de production des usines */
con capacite {j in Usines}:
sum {i in Clients} demande[i] * Affecter[i,j] <=
&CapaciteUsine * Construire[j];

/* Resolution du programme lineaire en nombres entiers */
solve obj Z with milp / primalin printfreq = 500;

for {i in Clients, j in Usines} Affecter[i,j] = round(Affecter[i,j]);
for {j in Usines} Construire[j] = round(Construire[j]);
num CDC = sum {i in Clients, j in Usines} dist[i,j] * Affecter[i,j].sol;
num CCU = sum {j in Usines} CoutUsine[j] * Construire[j].sol;
call symput('CDC', put(CDC,6.2));
call symput('CCU', put(CCU,7.2));
call symput('CT', put(Z,7.2));

/* Enregistrement des donnees sur les relations clients-usines */
create data Z_Data from
[Client Usine]={i in Clients, j in Usines: Affecter[i,j] = 1}
xi=x[i] yi=y[i] xj=x[j] yj=y[j];

/* Enregistrement des donnees sur les usines construites */
create data Usines_Construites from
[UsineConstruite]={j in Usines: Construire[j] = 1}
xj=x[j] yj=y[j];

/* Enregistrement des donnees sur les usines non construites */
create data Usines_NonConstruites from
[UsineNonConstruite]={j in Usines: Construire[j] = 0}
xj=x[j] yj=y[j];

quit;


/* Construction du graphe de la resolution du probleme */
title1 "Solution optimale du probleme";
title2 "Cout_Total = &CT";
title3 "Cout_deplacement_clients = &CDC, Cout_construction_usines = &CCU)";

data choixusine;
set Usines_Construites(rename=(xj=xu1)rename=(yj=yu1)) Usines_NonConstruites(rename=(xj=xu0)rename=(yj=yu0));
run;

data cudata;
set cdata(rename=(x=xc)rename=(y=yc)) choixusine;
run;

%annomac;
data anno(drop=xi yi xj yj);
%SYSTEM(2, 2, 2);
set Z_Data(keep=xi yi xj yj);
%LINE(xi, yi, xj, yj, grey, 1, 1);
run;

proc gplot data=cudata anno=anno;
axis1 label=none order=(0 to &xmax by 10);
axis2 label=none order=(0 to &ymax by 10);
symbol1 value=diamond interpol=none
pointlabel=("#NomClient" nodropcollisions color=black height=1) cv=black;
symbol2 value=dot interpol=none
pointlabel=("#UsineConstruite" nodropcollisions color=blue height=1) cv=blue;
symbol3 value=dot interpol=none
pointlabel=("#UsineNonConstruite" nodropcollisions color=red height=1) cv=red;
legend1 label = (color=green "LEGENDE") cborder = grey value = ("Clients" "Usines construites" "Usines non construites");
plot yc*xc yu1*xu1 yu0*xu0 / overlay haxis=axis1 vaxis=axis2 legend=legend1;
run;
quit;

/* Usines construites et usines non construites */
proc print data = choixusine;
title "Coordonnees de localisation des usines construites et non construites";
run;
