function p = read_nml(path)
% for reading simulation config*.nml. Fortran namelist is a standard
% format.
narginchk(1,1)

filename = get_configfile(path);

p = read_nml_group(filename, 'base');

if ~isfield(p, 'nml')
  p.nml = filename;
end

try %#ok<TRYNC>
p = merge_struct(p, read_nml_group(filename, 'setup'));
end

if isfield(p, 'flagdneu') && p.flagdneu
  p = merge_struct(p, read_nml_group(filename, 'neutral_perturb'));
end
if ~isfield(p, 'mloc')
  p.mloc=[];
end

if isfield(p, 'flagprecfile') && p.flagprecfile
  p = merge_struct(p, read_nml_group(filename, 'precip'));
end

if isfield(p, 'flagE0file') && p.flagE0file
  p = merge_struct(p, read_nml_group(filename, 'efield'));
end

if isfield(p, 'flagglow') && p.flagglow
  p = merge_struct(p, read_nml_group(filename, 'glow'));
end

end % function
