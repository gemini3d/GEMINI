function h = plot2D_curv(ymd,UTsec,xg,parm,parmlbl,caxlims,sourceloc,ha, cmap)
narginchk(7,9)

try
  axes(ha)
catch
  ha = axes('parent', ha);
end
%set(h,'PaperPosition',[0 0 11 4.5]);
if nargin<8 || isempty(ha)
  ha = axes('parent', figure);
end
if nargin<9 || isempty(cmap)
  cmap = parula(256);
end   

try
  axes(ha)
catch
  ha = axes('parent', ha);
end


%SOURCE LOCATION (SHOULD PROBABLY BE AN INPUT)
sourcemlat=sourceloc(1);
sourcemlon=sourceloc(2);


%SIZE OF SIMULATION
lx1=xg.lx(1); lx2=xg.lx(2); lx3=xg.lx(3);
inds1=3:lx1+2;
inds2=3:lx2+2;
inds3=3:lx3+2;
Re=6370e3;


%JUST PICK AN X3 LOCATION FOR THE MERIDIONAL SLICE PLOT, AND AN ALTITUDE FOR THE LAT./LON. SLICE
%ix3=floor(lx3/2);
ix3=1;
altref=300;
t=UTsec;


%SIZE OF PLOT GRID THAT WE ARE INTERPOLATING ONTO
meantheta=mean(xg.theta(:));
meanphi=mean(xg.phi(:));
%meanphi=xg.x3(inds3(1));     %dont' forget that x3 has ghost cells!!!
x=(xg.theta-meantheta);   %this is a mag colat. coordinate and is only used for defining grid in linspaces below
y=(xg.phi-meanphi);       %mag. lon coordinate
z=xg.alt/1e3;
lxp=1500;
lyp=500;
lzp=1500;
minx=min(x(:));
maxx=max(x(:));
miny=min(y(:));
maxy=max(y(:));
%minz=min(z(:));
minz=0;
maxz=max(z(:));
xp=linspace(minx,maxx,lxp);
yp=linspace(miny,maxy,lyp);
zp=linspace(minz,maxz,lzp)';

%{
%ix1s=floor(lx1/2):lx1;    %only valide for a grid which is symmetric aboutu magnetic equator... (I think)
ix1s=find(xg.x1(inds1)>=0);    %works for asymmetric grids
minz=0;
maxz=max(xg.alt(:));
[tmp,ix1]=min(abs(xg.alt(ix1s,1,1)-maxz*1e3));
ix1=ix1s(ix1);
thetavals=xg.theta(ix1:lx1,:,:);
meantheta=mean(thetavals(:));
phivals=xg.phi(ix1:lx1,:,:);
meanphi=mean(phivals(:));
x=(thetavals-meantheta);      %this is a mag colat. coordinate and is only used for defining grid in linspaces below and the parametric surfaces in the plots
y=(phivals-meanphi);          %mag. lon coordinate
z=xg.alt(ix1:lx1,:,:)/1e3;    %altitude
lxp=500;
lyp=500;
lzp=500;
minx=min(x(:));
maxx=max(x(:));%+0.5*(max(x(:))-min(x(:)));
miny=min(y(:));
maxy=max(y(:));
xp=linspace(minx,maxx,lxp);
yp=linspace(miny,maxy,lyp);
zp=linspace(minz,maxz,lzp)';
%}


%INTERPOLATE ONTO PLOTTING GRID
[X,Z]=meshgrid(xp,zp*1e3);    %meridional meshgrid


%DIRECT TO SPHERICAL
rxp=Z(:)+Re;
thetaxp=X(:)+meantheta;
%phixp=Y(:)+meanphi;


%NOW SPHERICAL TO DIPOLE
qplot=(Re./rxp).^2.*cos(thetaxp);
pplot=rxp/Re./sin(thetaxp).^2;
%phiplot=phixp;    %phi is same in spherical and dipole


%NOW WE CAN DO A `PLAID' INTERPOLATION - THIS ONE IS FOR THE MERIDIONAL SLICE
parmtmp=parm(:,:,ix3);
parmp=interp2(xg.x2(inds2),xg.x1(inds1),parmtmp,pplot,qplot);
parmp=reshape(parmp,lzp,lxp);    %slice expects the first dim. to be "y" ("z" in the 2D case)


%{
%LAT./LONG. SLICE COORDIANTES
zp2=[290,300,310];
lzp2=3;
[X2,Y2,Z2]=meshgrid(xp,yp,zp2*1e3);       %lat./lon. meshgrid, need 3D since and altitude slice cuts through all 3 dipole dimensions

rxp2=Z2(:)+Re;
thetaxp2=X2(:)+meantheta;
phixp2=Y2(:)+meanphi;

qplot2=(Re./rxp2).^2.*cos(thetaxp2);
pplot2=rxp2/Re./sin(thetaxp2).^2;
phiplot2=phixp2;    %phi is same in spherical and dipole


%NOW WE CAN DO A `PLAID' INTERPOLATION - THIS ONE IS FOR THE LAT/LON SLICE
parmtmp=permute(parm,[3,2,1]);
x3interp=xg.x3(inds3);
x3interp=x3interp(:);     %interp doesn't like it unless this is a column vector
parmp2=interp3(xg.x2(inds2),x3interp,xg.x1(inds1),parmtmp,pplot2,phiplot2,qplot2);
parmp2=reshape(parmp2,lyp,lxp,lzp2);    %slice expects the first dim. to be "y"
%}

%CONVERT ANGULAR COORDINATES TO MLAT,MLON
xp=90-(xp+meantheta)*180/pi;
[xp,inds]=sort(xp);
parmp=parmp(:,inds);
%parmp2=parmp2(:,inds,:);

%{
yp=(yp+meanphi)*180/pi;
[yp,inds]=sort(yp);
parmp=parmp(inds,:,:);
%parmp2=parmp2(inds,:,:);
%}

%COMPUTE SOME BOUNDS FOR THE PLOTTING
minxp=min(xp(:));
maxxp=max(xp(:));
minyp=min(yp(:));
maxyp=max(yp(:));
minzp=min(zp(:));
maxzp=max(zp(:));


%NOW THAT WE'VE SORTED, WE NEED TO REGENERATE THE MESHGRID
%[XP,YP,ZP]=meshgrid(xp,yp,zp);
FS=12;

%MAKE THE PLOT!
%subplot(121);
hi=imagesc(ha,xp,zp,parmp);
hold(ha,'on')
plot(ha,[minxp,maxxp],[altref,altref],'w--','LineWidth',2);
plot(ha,sourcemlat,0,'r^','MarkerSize',8,'LineWidth',2);
hold(ha,'off')
set(hi,'alphadata',~isnan(parmp));
set(ha,'FontSize',FS)
axis(ha,'xy')
colormap(ha,cmap)
caxis(ha,caxlims)
c=colorbar(ha);
xlabel(c,parmlbl)
xlabel(ha,'magnetic latitude (deg.)')
ylabel(ha,'altitude (km)')


%{
subplot(122);
hi=imagesc(xp,yp,parmp2(:,:,2));
hold on;
plot([minxp,maxxp],[sourcemlon,sourcemlon],'w--','LineWidth',2);
plot(sourcemlat,sourcemlon,'r^','MarkerSize',12,'LineWidth',2);
hold off;
set(hi,'alphadata',~isnan(parmp2(:,:,2)));
set(gca,'FontSize',FS);
axis xy;
axis tight;
colormap(cmap)
caxis(caxlims)
c=colorbar;
xlabel(c,parmlbl)
xlabel('magnetic latitude (deg.)')
ylabel('magnetic longitude (deg.)')
%}


%CONSTRUCT A STRING FOR THE TIME AND DATE
%subplot(121);
UThrs=floor(t/3600);
UTmin=floor((t/3600-UThrs)*60);
UTsec=floor((t/3600-UThrs-UTmin/60)*3600);
UThrsstr=num2str(UThrs);
UTminstr=num2str(UTmin);
if (numel(UTminstr)==1)
  UTminstr=['0',UTminstr];
end
UTsecstr=num2str(UTsec);
if (numel(UTsecstr)==1)
  UTsecstr=['0',UTsecstr];
end

timestr=[UThrsstr,':',UTminstr,':',UTsecstr];
strval=sprintf('%s \n %s',[num2str(ymd(2)),'/',num2str(ymd(3)),'/',num2str(ymd(1))], ...
    [timestr,' UT']);
%text(xp(round(lxp/10)),zp(lzp-round(lzp/7.5)),strval,'FontSize',18,'Color',[0.66 0.66 0.66],'FontWeight','bold');
%text(xp(round(lxp/10)),zp(lzp-round(lzp/7.5)),strval,'FontSize',16,'Color',[0.5 0.5 0.5],'FontWeight','bold');
title(ha,strval);

end % function
