% DATAONENODE A class that represents a DataONE Node
%
% This work was created by participants in the DataONE project, and is
% jointly copyrighted by participating institutions in DataONE. For
% more information on DataONE, see our web site at http://dataone.org.
%
%   Copyright 2009-2015 DataONE
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

classdef DataONENode < hgsetget
    
    properties
        
        % The DataONE base url with version, used to construct REST endpoints for the node
        node_base_service_url;
        
        % The DataONE identifier for the node 
        node_id;
        
        % The DataONE node type (either 'cn' of 'mn')
        node_type;
        
        
    end
    
    properties (Access = 'private')
                
    end
    
    methods
            
    end
    
    methods (Access = 'private')
        
    end
end