function vardata = ncread( source, varname, varargin )
% NCREAD A provenance wrapper function to the builtin NetCDF ncread
%    VARDATA = NCREAD(FILENAME,VARNAME) reads data from the variable
%    VARNAME in the NetCDF file FILENAME, and generates provenance
%    information about the read event.
%
%    VARDATA = NCREAD(OPENDAP_URL,VARNAME) reads data from the variable
%    VARNAME from an OPeNDAP NetCDF data source, and generates provenance
%    information about the read event.
%
%    VARDATA = NCREAD(SOURCE,VARNAME,START, COUNT) 
%    VARDATA = NCREAD(SOURCE,VARNAME,START, COUNT, STRIDE) reads data from
%    VARNAME beginning at the location given by START from SOURCE, which
%    can either be a filename or an OPeNDAP URL, and generates provenance
%    information about the read event. For an N-dimensional
%    variable START is a vector of 1-based indices of length N specifying
%    the starting location. COUNT is also a vector of length N specifying
%    the number of elements to read along corresponding dimensions. If a
%    particular element of COUNT is Inf, data is read until the end of that
%    dimension. The optional argument STRIDE specifies the inter-element
%    spacing along each dimension. STRIDE defaults to a vector of ones.
%
% This work was created by participants in the DataONE project, and is
% jointly copyrighted by participating institutions in DataONE. For
% more information on DataONE, see our web site at http://dataone.org.
%
%   Copyright 2015 DataONE
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.

    disp('Called the ncread wrapper function.');

    % Remove wrapper ncread from the Matlab path
    overloadedFunctPath = which('ncread');
    [overloaded_func_path, func_name, ext] = fileparts(overloadedFunctPath);
    rmpath(overloaded_func_path);    
    disp('remove the path of the overloaded ncread function.');  
    
    % Call ncread 
    vardata = ncread( source, varname, varargin{:} );
    % celldisp(varargin);

    % Add the wrapper ncread back to the Matlab path
    addpath(overloaded_func_path, '-begin');
    disp('add the path of the overloaded ncread function back.');
    
    % Identifiy the file being used and add a prov:used statement 
    % in the RunManager DataPackage instance
  
    import org.dataone.client.run.RunManager;
    import java.net.URI;
    
    runManager = RunManager.getInstance();   
    % dataPackage = runManager.getDataPackage();    
    % d1_cn_resolve_endpoint = runManager.getD1_CN_Resolve_Endpoint();
    
    % sourceURISet = {URI(source)};
    % predicate = PROV.predicate('used');
    % execURI = URI([d1_cn_resolve_endpoint  'execution_' runManager.runId]);
   
    exec_input_id_list = runManager.getExecInputIds();
    
    startIndex = regexp( char(source),'http' ); 
    if isempty(startIndex)
        %fullSourcePath = [pwd(), filesep,source];
        %fullSourcePath = which(source);
        [status, struc] = fileattrib(source);
        fullSourcePath = struc.Name;
                
        exec_input_id_list.put(fullSourcePath, 'application/netcdf');
    else
        exec_input_id_list.put(source, 'application/netcdf');
    end

end

