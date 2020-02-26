function ok = compare_all(outdir, refdir)

% the absolute and relative tolerance account for slight IEEE-754 based differences,
% including non-associativity of floating-point arithmetic.
% these parameters are a bit arbitrary.

% per MZ Oct 17, 2018:
% Ti,Te=1 K
% ne=1e6 m-3
% vi,v2,v3=1 m/s
% J1,J2,J3 = 1e-9

% MZ wants to change what we consider signficant...
% Ti,Te=5 K
% ne=1e7 m-3
% vi,v2,v3=2 m/s
% J1,J2,J3 = 1e-9
narginchk(2,2)

cwd = fileparts(mfilename('fullpath'));
addpath([cwd,'/../script_utils'], [cwd, '/../vis'])

tol.rtol = 1e-5;
tol.rtolN = 1e-5;
tol.rtolT = 1e-5;
tol.rtolJ = 1e-5;
tol.rtolV = 1e-5;
tol.atol=1e-8;
tol.atolN=1e9;
tol.atolT=100;
tol.atolJ=1e-7;
tol.atolV=50;

outdir = absolute_path(outdir);
refdir = absolute_path(refdir);

exist_or_skip(outdir, 'dir')
exist_or_skip(refdir, 'dir')
%% check that paths not the same
if strcmp(outdir, refdir), error([outdir, ' and ', refdir, ' directories are the same']), end
%% READ IN THE SIMULATION INFORMATION
params = read_config([outdir, filesep, 'inputs']);

lxs = simsize(outdir);
lxs_ref = simsize(refdir);
if ~all(lxs==lxs_ref)
  error(['ref dims ',int2str(lxs_ref), ' != this sim dims ', int2str(lxs)])
end

disp(['sim grid dimensions: ',num2str(lxs)])

%% TIMES OF INTEREST
times = params.UTsec0:params.dtout:params.UTsec0 + params.tdur;
Nt = length(times);
assert(Nt > 1, [outdir, ' simulation did not run long enough'])

ymd=params.ymd;
UTsec=params.UTsec0;

ok = false;

for it=1:Nt
  st = ['UTsec ', num2str(times(it))];
  [neA,~,~,~,v1A,TiA,TeA,J1A,v2A,v3A,J2A,J3A] = loadframe(outdir,ymd,UTsec);
  [neB,~,~,~,v1B,TiB,TeB,J1B,v2B,v3B,J2B,J3B] = loadframe(refdir,ymd,UTsec);

  ok = ok + ~assert_allclose(neA,neB,tol.rtolN,tol.atolN,['Ne ',st], true);

  if false
    ok = ok + ~assert_allclose(v1A,v1B,tol.rtolV,tol.atolV,['V1 ', st], true);
  end
  ok = ok + ~assert_allclose(v2A,v2B,tol.rtolV,tol.atolV,['V2 ', st], true);
  ok = ok + ~assert_allclose(v3A,v3B,tol.rtolV,tol.atolV,['V3 ', st], true);

  if false
    ok = ok + ~assert_allclose(TiA,TiB,tol.rtolT,tol.atolT,['Ti ', st], true);
  end
  ok = ok + ~assert_allclose(TeA,TeB,tol.rtolT,tol.atolT,['Te ', st], true);

  ok = ok + ~assert_allclose(J1A,J1B,tol.rtolJ,tol.atolJ,['J1 ', st], true);
  ok = ok + ~assert_allclose(J2A,J2B,tol.rtolJ,tol.atolJ,['J2 ', st], true);
  ok = ok + ~assert_allclose(J3A,J3B,tol.rtolJ,tol.atolJ,['J3 ', st], true);

  %% assert time steps have unique output (earth always rotating...)
  if it>1
    ok = ok + ~assert_allclose(Ne,neA,tol.rtol,tol.atol,['Ne ', st,' too similar to prior step'],true, true);
    %ok = ok + ~assert_allclose(v1,v1A,tol.rtol,tol.atol,['V1 ', st,' too similar to prior step'],true, true);
    ok = ok + ~assert_allclose(v2,v2A,tol.rtol,tol.atol,['V2 ', st,' too similar to prior step'],true, true);
    ok = ok + ~assert_allclose(v3,v3A,tol.rtol,tol.atol,['V3 ', st,' too similar to prior step'],true, true);
  end
  if it==3
   %ok = ok + ~assert_allclose(Ti,TiA,tol.rtol,tol.atol,['Ti ', st,' too similar to prior step'],true, true);
    ok = ok + ~assert_allclose(Te,TeA,tol.rtol,tol.atol,['Te ', st,' too similar to prior step'],true, true);
  end
  if it==2
    ok = ok + ~assert_allclose(J1,J1A,tol.rtol,tol.atol,['J1 ', st,' too similar to prior step'],true,true, true);
    ok = ok + ~assert_allclose(J2,J2A,tol.rtol,tol.atol,['J2 ', st,' too similar to prior step'],true,true, true);
    ok = ok + ~assert_allclose(J3,J3A,tol.rtol,tol.atol,['J3 ', st,' too similar to prior step'],true,true, true);
  end

  Ne = neA; v1=v1A; v2=v2A; v3=v3A; Ti=TiA; Te=TeA; J1=J1A; J2=J2A; J3=J3A;

  [ymd,UTsec] = dateinc(params.dtout,ymd,UTsec);

end

if ok ~= 0
  error([int2str(ok), ' compare errors'])
else
  disp(['OK: Gemini output comparison of ',int2str(Nt),' time steps.'])
end

if nargout==0, clear('ok'), end

end % function
