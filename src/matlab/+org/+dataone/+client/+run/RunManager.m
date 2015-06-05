% RUNMANAGER A class used to track information about program runs.
%   The RunManager class provides functions to manage script runs in terms
%   of the known file inputs and the derived file outputs. It keeps track
%   of the provenance (history) relationships between these inputs and outputs.
%
% This work was created by participants in the DataONE project, and is
% jointly copyrighted by participating institutions in DataONE. For
% more information on DataONE, see our web site at http://dataone.org.
%
%   Copyright 2009-2014 DataONE
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

classdef RunManager < hgsetget

    properties
       
        % The instance of the Configuration class used to provide settings 
        % details for this RunManager
        configuration;
                
        % The execution metadata associated with this run
        execution;
        
        % The YesWorkflow Extractor object
        extractor;
        
        % The YesWorkflow Modeler object
        modeler;
        
        % The YesWorkflow Grapher object
        grapher;
        
        % The generated workflow object built by YesWorkflow 
        workflow;
               
        % The provenance directory for an execution
        runDir;
    end

    properties (Access = private)
               
        % Enable or disable the provenance capture state
        prov_capture_enabled = false;

        % The state of a recording session
        recording = false;
        
        % The DataPackage aggregating and describing all objects in a run
        dataPackage;
        
        processViewDotFileName = '';
        dataViewDotFileName = '';
        combinedViewDotFileName = '';
        
        processViewPdfFileName = '';
        dataViewPdfFileName = '';
        combinedViewPdfFileName = '';
        
        wfMetaFileName = '';
    end
   
    methods (Access = private)

        function manager = RunManager(configuration)
            % RUNMANAGER Constructor: creates an instance of the RunManager class
            %   The RunManager class manages outputs of a script based on the
            %   settings in the given configuration passed in.            
            import org.dataone.client.configure.Configuration;
            manager.configuration = configuration;
            configuration.saveConfig();
            manager.init();
            mlock; % Lock the RunManager instance to prevent clears          
        end
        
    end

    methods (Static)
        function runManager = getInstance(configuration)
            % GETINSTANCE returns an instance of the RunManager by either
            % creating a new instance or returning an existing one.
                        
            import org.dataone.client.configure.Configuration;
            
            %% Set all jars under lib/java/ to the java dynamic class path (Need further consideration !)
            % RunManager.setJavaClassPath();
                       
            % Set the java class path
            RunManager.setMatlabPath();

            % Create a default configuration object if one isn't passed in
            if ( nargin < 1 )
                configuration = Configuration();
               
            end
            
            persistent singletonRunManager; % private, stays in memory across clears
            
            if isempty( singletonRunManager )
                import org.dataone.client.run.RunManager;
                runManager = RunManager(configuration);
                singletonRunManager = runManager;
                
            else
                runManager = singletonRunManager;
                
            end
        end
        
        function setJavaClassPath()
            % SETJAVACLASSPATH adds all Java libraries found in 
            % $matalab-dataone/lib to the java class path
            
            % Determine the lib directory relative to the RunManager
            % location
            filePath = mfilename('fullpath');
            matlab_dataone_dir_array = strsplit(filePath, filesep);
            matlab_dataone_java_lib_dir = ...
                [strjoin( ...
                    matlab_dataone_dir_array(1:length(matlab_dataone_dir_array) - 7), ...
                    filesep) ...
                    filesep 'lib' filesep 'java' filesep];
            java_libs_array = dir(matlab_dataone_java_lib_dir);
            % For each library file, add it to the class path
            
            classpath = javaclasspath('-all');
            
            for i=3:length(java_libs_array)
                classpathItem = [matlab_dataone_java_lib_dir java_libs_array(i).name];
                presentInClassPath = strmatch(classpathItem, classpath);
                if ( isempty(presentInClassPath) )
                    javaaddpath(classpathItem);
                    disp(['Added new java classpath item: ' classpathItem]);
                end
                
            end
        end
        
        function setMatlabPath()
            % SETMATLABPATH adds all Matlab libraries found in 
            % $matalab-dataone/lib/matlab to the Matlab path
            
            % Determine the lib directory relative to the RunManager
            % location
            filePath = mfilename('fullpath');
            matlab_dataone_dir_array = strsplit(filePath, filesep);
            matlab_dataone_lib_dir = ...
                [strjoin( ...
                    matlab_dataone_dir_array(1:length(matlab_dataone_dir_array) - 7), ...
                    filesep) ...
                    filesep 'lib' filesep 'matlab' filesep];
           
           % Add subdirectories of lib/matlab to the Matlab path,
           addpath(genpath(matlab_dataone_lib_dir));
                
        end
    end
    
    methods  
        function configYesWorkflow(runManager, path)
            % CONFIGYESWORKFLOW set YesWorkflow extractor language model to be
            % Matlab type
            import org.yesworkflow.extract.DefaultExtractor;
            import org.yesworkflow.model.DefaultModeler;
            import org.yesworkflow.graph.DotGrapher;
            import java.io.PrintStream;
            
            runManager.extractor = DefaultExtractor;
            runManager.modeler = DefaultModeler;
            runManager.grapher = DotGrapher(java.lang.System.out, java.lang.System.err);
            
            % Configure yesWorkflow language model to be Matlab
            import org.yesworkflow.extract.HashmapMatlabWrapper;
            import org.yesworkflow.Language;
            
            config = HashmapMatlabWrapper;
            config.put('language', Language.MATLAB);
            runManager.extractor = runManager.extractor.configure(config);         
          
            % Set generate_workflow_graphic to be true
            runManager.configuration.generate_workflow_graphic = true;
        end
        
                
        function data_package = record(runManager, filePath, tag)
            % RECORD Records provenance relationships between data and scripts
            % When record() is called, data input files, data output files,
            % and programs (scripts and classes) are tracked during an
            % execution of the program, and a graph of their relationships
            % is produced using the W3C PROV ontology standard 
            % (<http://www.w3.org/TR/prov-o/>) and the
            % DataONE ProvONE model(<https://purl.dataone.org/provone-v1-dev>).
            % Note that, when passing scripts to the record() function,
            % scripts that contain commands such as 'clear all' will cause
            % the recording session to fail because the RunManager instance
            % will have been removed. Also, note that relative path names
            % to files may also cause I/O errors, depending on what your
            % current working directory is at the moment.

            % Return if we are already recording
            if ( runManager.recording )
                return;
            end
                   
            % Do we have a script as input?
            if ( nargin < 2 )
                error(['Please provide the path to the script you want to ' ...
                       'record, and (optionally) a tag that labels your run.']);
            end
            
            % Does the script exist?
            if ( ~exist(filePath, 'file'));
                error([' The script: '  filePath ' does not exist.' ...
                       'Please provide the path to the script you want to ' ...
                       'record, and (optionally) a tag that labels your run.']);                    
            end
            
            % do we have a tag?
            if ( nargin < 3 )
                tag = ''; % otherwise use an empty tag
                    
            end
                        
            % Begin collecting execution metadata
            import org.dataone.client.run.Execution;
                
            % Validate the tag, ensuring it can be cast to a string
            try
                tagStr = '';
                if ( ~isempty(tag) )
                    tagStr = cast(tag);
                end
                
            catch classCastException
                error(['The tag used for the record session cannot be ' ...
                       'cast to a string. Please use a tag label that is ' ...
                       ' a string or a data type that can be cast to ' ...
                       'a string. The error message was: ' ...
                       classCastException.message]);
            end
            
            runManager.execution = Execution(tagStr);
            runManager.execution.software_application = filePath; % Set script path
            
            % Set up YesWorkflow and pass the path of a script to
            % YesWorkflow
            runManager.configYesWorkflow(runManager.execution.software_application);
            
            % Begin recording
            runManager.startRecord(runManager.execution.tag);

            % End the recording session
            runManager.dataPackage = runManager.endRecord();          
        end
        
        function startRecord(runManager, tag)
            % STARTRECORD Starts recording provenance relationships (see record()).

            if ( runManager.recording )
                warning(['A RunManager session is already active. Please call ' ...
                         'endRecord() if you wish to close this session']);
                  
            end                

            % Compute script_base_name if it is not assigned a value
            if isempty(runManager.configuration.script_base_name)
                [pathstr,script_base_name,ext] = fileparts(runManager.execution.software_application);
                runManager.configuration.script_base_name = strtrim(script_base_name);      
            end
            
            %disp(runManager.configuration.script_base_name);
            
            % Create the run metadata directory for this run
            k = strfind(runManager.execution.execution_id, 'urn:uuid:'); % get the index of 'urn:uuid:'
            runId = runManager.execution.execution_id(k+9:end);
            runManager.runDir = strcat(runManager.configuration.provenance_storage_directory, filesep,'runs', filesep, runId);
            [status, message, message_id] = mkdir(runManager.runDir);
            
            if ( status ~= 1 )
                error(message_id, [ 'The directory %s' ...
                    ' could not be created. The error message' ...
                    ' was: ' runManager.runDir, message]);
            end
          
            %% Package a datapackage for the current run    
            % Initialize a dataPackage to manage the run
            import org.dataone.client.v1.itk.DataPackage;
            import org.dataone.service.types.v1.Identifier;
            import org.dataone.ore.HashmapMatlabWrapper;
            import org.dspace.foresite.ResourceMap;
            import org.dataone.client.run.NamedConstant;
            import org.dataone.client.v1.itk.ArrayListMatlabWrapper;
            import org.dataone.client.v1.types.D1TypeBuilder;
            import org.dataone.client.v1.itk.D1Object;
            import java.io.File;
            import javax.activation.DataSource;
            import javax.activation.FileDataSource;
            
            packageIdentifier = Identifier();
            packageIdentifier.setValue(runManager.execution.data_package_id);            
            % runManager.dataPackage = DataPackage(packageIdentifier);
           
            % Create a resourceMap identifier
            resourceMapId = Identifier;
            resourceMapId.setValue(['resourceMap_' char(java.util.UUID.randomUUID())]);
            % Create a datapackage with resourceMapId
            runManager.dataPackage = DataPackage(resourceMapId);
            
            % Record relationship identifying execution id as a provone:Execution
            executionId = Identifier;
            executionId.setValue(['execution_' runId]);
            
            provOneExecIdsList = ArrayListMatlabWrapper;
            provOneExecId = Identifier;
            provOneExecId.setValue(NamedConstant.provONEexecution);
            provOneExecIdsList.add(provOneExecId);
            runManager.dataPackage.insertRelationship(executionId, provOneExecIdsList, NamedConstant.RDF_NS, NamedConstant.rdfType);                    
              
            % Record relationship identifying workflow id as a provONE:Program
            wfId = Identifier;
            E = strsplit(runManager.execution.software_application,filesep);          
            wfId.setValue(char(E(end)));
        
            provOneProgramIdsList = ArrayListMatlabWrapper;
            provOneProgramId = Identifier;
            provOneProgramId.setValue(NamedConstant.provONEprogram);
            provOneProgramIdsList.add(provOneProgramId);
            runManager.dataPackage.insertRelationship(wfId, provOneProgramIdsList, NamedConstant.RDF_NS, NamedConstant.rdfType);
         
            % Record relationship identifying prov:hadPlan between execution and programs           
            wfIdsList = ArrayListMatlabWrapper;
            wfIdsList.add(wfId);
            wfMetadataId = Identifier;
            runManager.wfMetaFileName = [runManager.configuration.script_base_name '_meta1.1'];
            wfMetadataId.setValue(runManager.wfMetaFileName);
            runManager.dataPackage.insertRelationship(wfMetadataId, wfIdsList); % Attention here: add a sciemetadata to a program, so the program can be added to the aggregation. Only DataPackage.addData() can not achieve this.       
          
            % Store the prov relationship: execution->prov:qualifiedAssociation->association
            associationId = Identifier;
            associationId.setValue(['A0_' char(java.util.UUID.randomUUID())]);
            provAssociationId = Identifier;
            provAssociationId.setValue(NamedConstant.provAssociation);
            provAssociationIdsList = ArrayListMatlabWrapper;
            provAssociationIdsList.add(provAssociationId);
            
            % Store the prov relationship: association->prov:hadPlan->program
            runManager.dataPackage.insertRelationship(associationId, wfIdsList, NamedConstant.provNS, NamedConstant.provHadPlan);
            % Record relationship identifying association id as a prov:Association
            runManager.dataPackage.insertRelationship(associationId, provAssociationIdsList, NamedConstant.RDF_NS, NamedConstant.rdfType);
            
            associationIdsList = ArrayListMatlabWrapper;
            associationIdsList.add(associationId);
            runManager.dataPackage.insertRelationship(executionId, associationIdsList, NamedConstant.provNS, NamedConstant.provQualifiedAssociation);
           
            % Store the ProvONE relationships for user
            userId = Identifier;
            userId.setValue(runManager.execution.account_name);           
            userIdsList = ArrayListMatlabWrapper;           
            userIdsList.add(userId);
            
            % Record a relationship identifying the provONE:user
            provONEUser = Identifier;
            provONEUser.setValue(NamedConstant.provONEuser);
            provONEUserList = ArrayListMatlabWrapper;
            provONEUserList.add(provONEUser);
            runManager.dataPackage.insertRelationship(userId, provONEUserList, NamedConstant.RDF_NS, NamedConstant.rdfType);
            
            % Record the relationship between the Execution and the user
            runManager.dataPackage.insertRelationship(executionId, userIdsList, NamedConstant.provONE_NS, NamedConstant.provWasAssociatedWith);
       
            % Record the relationship for association->prov:agent->"user"
            runManager.dataPackage.insertRelationship(associationId, userIdsList, NamedConstant.provNS, NamedConstant.provAgent);            
          
            %% Run the script and collect provenance information
          % runManager.prov_capture_enabled = true;
          % [pathstr, script_name, ext] = ...
          %     fileparts(runManager.execution.software_application);
          % addpath(pathstr);

          % try
          %     eval(script_name);
                
          % catch runtimeError
          %     error(['The script: ' ...
          %            runManager.execution.software_application ...
          %            ' could not be run. The error message was: ' ...
          %             runtimeError.message]);
                   
          % end
          
        end
        
        function data_package = endRecord(runManager)
            % ENDRECORD Ends the recording of an execution (run).
            
            import org.dataone.service.types.v1.Identifier;
            import org.dataone.client.v1.itk.ArrayListMatlabWrapper; 
            import org.dataone.client.v1.itk.D1Object;
            import org.dataone.client.v1.itk.DataPackage;
            import org.dataone.client.run.NamedConstant;
            import java.io.File;
            import javax.activation.FileDataSource;
            import org.dataone.client.v1.types.D1TypeBuilder;
            
            % Stop recording
            runManager.recording = false;
            runManager.prov_capture_enabled = false;
            
            % Create the runId again. There is a runId created in startRecord() already. 
            k = strfind(runManager.execution.execution_id, 'urn:uuid:'); % get the index of 'urn:uuid:'
            runId = runManager.execution.execution_id(k+9:end);
            % Record relationship identifying execution id as a provone:Execution
            executionId = Identifier;
            executionId.setValue(['execution_' runId]);
            
            % Record a data list for provOne:Data
            provONEdataId = Identifier;
            provONEdataId.setValue(NamedConstant.provONEdata);
            provONEdataIdsList = ArrayListMatlabWrapper;
            provONEdataIdsList.add(provONEdataId);
            
            % Get submitter and MN node reference
            submitter = runManager.execution.account_name;
            mnNodeId = runManager.configuration.target_member_node_id;
            
            % Create a D1Object for the program that we are running and add to the datapackage
            fileId = File(runManager.execution.software_application);
            data = FileDataSource(fileId);           
            scriptFmt = 'text/plain';        
            wfId = Identifier;
            E = strsplit(runManager.execution.software_application,filesep);          
            wfId.setValue(char(E(end)));        
            programD1Obj = D1Object(wfId, data, D1TypeBuilder.buildFormatIdentifier(scriptFmt), D1TypeBuilder.buildSubject(submitter), D1TypeBuilder.buildNodeReference(mnNodeId));
            runManager.dataPackage.addData(programD1Obj);
            
            % Generate YesWorkflow image outputs
            if runManager.configuration.generate_workflow_graphic
                % Call YesWorkflow to capture prospective provenance for current scirpt
                curDir = pwd();
                runManager.captureProspectiveProvenanceWithYW();
                cd(runManager.runDir);
                
                runManager.combinedViewPdfFileName = [runManager.configuration.script_base_name '_combined_view.pdf'];
                runManager.dataViewPdfFileName = [runManager.configuration.script_base_name '_data_view.pdf'];
                runManager.processViewPdfFileName = [runManager.configuration.script_base_name '_process_view.pdf'];
                    
                % Convert .gv files to .pdf files
                if isunix    
                    system(['/usr/local/bin/dot -Tpdf '  runManager.processViewDotFileName ' -o ' runManager.processViewPdfFileName]);  
                    system(['/usr/local/bin/dot -Tpdf '  runManager.combinedViewDotFileName ' -o ' runManager.combinedViewPdfFileName]); % for linux & mac platform, not for windows OS family             
                    system(['/usr/local/bin/dot -Tpdf '  runManager.dataViewDotFileName ' -o ' runManager.dataViewPdfFileName]);      
                          
                    delete(runManager.combinedViewDotFileName);
                    delete(runManager.dataViewDotFileName);
                    delete(runManager.processViewDotFileName);
                end    
                cd(curDir);
            end
            
            % Include YW impages
            if runManager.configuration.include_workflow_graphic 
                % One derived YW combined view image 
                imgId1 = Identifier;
                imgId1.setValue(runManager.combinedViewPdfFileName); % a figure image
                % Metadata
                metadataImgId1 = Identifier;
                metadataImgId1.setValue([runManager.configuration.script_base_name '_combined_view.xml']);
                dataImgIds1 = ArrayListMatlabWrapper;
                dataImgIds1.add(imgId1); 
                
                % One derived YW data view image
                imgId2 = Identifier;
                imgId2.setValue(runManager.dataViewPdfFileName); % a figure image
                % Metadata
                metadataImgId2 = Identifier;
                metadataImgId2.setValue([runManager.configuration.script_base_name '_data_view.xml']);
                dataImgIds2 = ArrayListMatlabWrapper;
                dataImgIds2.add(imgId2);
                 
                % One derived YW process view image
                imgId3 = Identifier;
                imgId3.setValue(runManager.processViewPdfFileName); % a figure image
                % Metadata
                metadataImgId3 = Identifier;
                metadataImgId3.setValue([runManager.configuration.script_base_name '_process_view.xml']);
                dataImgIds3 = ArrayListMatlabWrapper;
                dataImgIds3.add(imgId3);
                 
                % wasDocumentedBy
                runManager.dataPackage.insertRelationship(metadataImgId1, dataImgIds1);
                runManager.dataPackage.insertRelationship(metadataImgId2, dataImgIds2);
                runManager.dataPackage.insertRelationship(metadataImgId3, dataImgIds3);
                
                % wasGeneratedBy
                execActivityIdList = ArrayListMatlabWrapper;
                execActivityIdList.add(executionId);
                runManager.dataPackage.insertRelationship(imgId1, execActivityIdList, NamedConstant.provNS, NamedConstant.provWasGeneratedBy);  
                runManager.dataPackage.insertRelationship(imgId2, execActivityIdList, NamedConstant.provNS, NamedConstant.provWasGeneratedBy);  
                runManager.dataPackage.insertRelationship(imgId3, execActivityIdList, NamedConstant.provNS, NamedConstant.provWasGeneratedBy);  
                
                % Record relationship identifying as provONE:Data
                runManager.dataPackage.insertRelationship(imgId1, provONEdataIdsList, NamedConstant.provONE_NS, NamedConstant.provONEdata);
                runManager.dataPackage.insertRelationship(imgId2, provONEdataIdsList, NamedConstant.provONE_NS, NamedConstant.provONEdata);
                runManager.dataPackage.insertRelationship(imgId3, provONEdataIdsList, NamedConstant.provONE_NS, NamedConstant.provONEdata);
                
                % Create D1Object for each figure and add the D1Object to the dataPackage
                cd(runManager.runDir);
                imgFmt = 'application/pdf';      
                img1FileId = File(imgId1.getValue());
                img1Data = FileDataSource(img1FileId);
                img1D1Obj = D1Object(imgId1, img1Data, D1TypeBuilder.buildFormatIdentifier(imgFmt), D1TypeBuilder.buildSubject(submitter), D1TypeBuilder.buildNodeReference(mnNodeId));
                runManager.dataPackage.addData(img1D1Obj);
             
                img2FileId = File(imgId2.getValue());
                img2Data = FileDataSource(img2FileId);
                img2D1Obj = D1Object(imgId2, img2Data, D1TypeBuilder.buildFormatIdentifier(imgFmt), D1TypeBuilder.buildSubject(submitter), D1TypeBuilder.buildNodeReference(mnNodeId));
                runManager.dataPackage.addData(img2D1Obj);
                
                img3FileId = File(imgId3.getValue());
                img3Data = FileDataSource(img3FileId);
                img3D1Obj = D1Object(imgId3, img3Data, D1TypeBuilder.buildFormatIdentifier(imgFmt), D1TypeBuilder.buildSubject(submitter), D1TypeBuilder.buildNodeReference(mnNodeId));
                runManager.dataPackage.addData(img3D1Obj);
              
                % Create yesWorkflow modelFacts prolog dump 
                import org.yesworkflow.model.ModelFacts;
                import org.yesworkflow.extract.ExtractFacts;
                
                modelFacts = runManager.modeler.getFacts();
                
                mfilename = [runManager.configuration.script_base_name  '_ywModelFacts.pl'];
                fw = fopen(mfilename, 'w'); 
                if fw == -1, error('Cannot write "%s%".',mfilename); end
                fprintf(fw, '%s', char(modelFacts));
                fclose(fw);
               
                metadataModelFactsId1 = Identifier;
                metadataModelFactsId1.setValue([runManager.configuration.script_base_name  '_ywModelFacts.xml']);
                dataModelFactsIds1 = ArrayListMatlabWrapper;
                modelFactsId1 = Identifier;
                modelFactsId1.setValue(mfilename); % ywModelFacts prolog dump
                dataModelFactsIds1.add(modelFactsId1); 
           
                % Record wasDocumentedBy / wasGeneratedBy / provONE:Data relationships for ywModelFacts prolog dump
                runManager.dataPackage.insertRelationship(metadataModelFactsId1, dataModelFactsIds1);
                runManager.dataPackage.insertRelationship(modelFactsId1, execActivityIdList, NamedConstant.provNS, NamedConstant.provWasGeneratedBy);  
                runManager.dataPackage.insertRelationship(modelFactsId1, provONEdataIdsList, NamedConstant.provONE_NS, NamedConstant.provONEdata);
                  
                % Create D1Object for ywModelFacts prolog dump and add the D1Object to the DataPackage
                prologDumpFmt = 'text/plain';      
                modelFactsFileId = File(modelFactsId1.getValue());
                modelFactsData = FileDataSource(modelFactsFileId);
                modelFactsD1Obj = D1Object(modelFactsId1, modelFactsData, D1TypeBuilder.buildFormatIdentifier(prologDumpFmt), D1TypeBuilder.buildSubject(submitter), D1TypeBuilder.buildNodeReference(mnNodeId));
                runManager.dataPackage.addData(modelFactsD1Obj);
                
                % Create yewWorkflow extractFacts prolog dump
                extractFacts = runManager.extractor.getFacts();
                
                efilename = [runManager.configuration.script_base_name  '_ywExtractFacts.pl'];
                fw = fopen(efilename, 'w');    
                if fw == -1, error('Cannot write "%s%".',efilename); end
                fprintf(fw, '%s', char(extractFacts));
                fclose(fw);
                
                metadataExtractFactsId1 = Identifier;
                metadataExtractFactsId1.setValue([runManager.configuration.script_base_name  '_ywExtractFacts.xml']);
                dataExtractFactsIds1 = ArrayListMatlabWrapper;
                extractFactsId1 = Identifier;
                extractFactsId1.setValue(efilename); % ywExtractFacts prolog dump
                dataExtractFactsIds1.add(extractFactsId1); 
           
                % Record wasDocumentedBy / wasGeneratedBy / provONE:Data relationships for ywExtractFacts prolog dump
                runManager.dataPackage.insertRelationship(metadataExtractFactsId1, dataExtractFactsIds1);
                runManager.dataPackage.insertRelationship(extractFactsId1, execActivityIdList, NamedConstant.provNS, NamedConstant.provWasGeneratedBy);  
                runManager.dataPackage.insertRelationship(extractFactsId1, provONEdataIdsList, NamedConstant.provONE_NS, NamedConstant.provONEdata);
                  
                % Create D1Object for ywExtractFacts prolog dump and add the D1Object to the DataPackage      
                extractFactsFileId = File(extractFactsId1.getValue());
                extractFactsData = FileDataSource(extractFactsFileId);
                extractFactsD1Obj = D1Object(extractFactsId1, extractFactsData, D1TypeBuilder.buildFormatIdentifier(prologDumpFmt), D1TypeBuilder.buildSubject(submitter), D1TypeBuilder.buildNodeReference(mnNodeId));
                runManager.dataPackage.addData(extractFactsD1Obj);
                
                cd(curDir);
            end               

            % Create resource map
            resourceMap = runManager.dataPackage.getMap();
            
            % Create a new Agent  
            import org.dspace.foresite.Agent;
            import org.dspace.foresite.OREFactory;
            import org.dataone.ore.ResourceMapFactory;
            
            creator = OREFactory.createAgent();
            creator.addName(runManager.execution.account_name);
            resourceMap.addCreator(creator);
            
            % Serialize a datapackage
            rdfXml = ResourceMapFactory.getInstance().serializeResourceMap(resourceMap);
            
            % Print it
            cd(runManager.runDir);
            resourceMapName = ['resourceMap_' runManager.configuration.script_base_name '.xml'];
            fw = fopen(resourceMapName, 'w'); 
            if fw == -1, error('Cannot write "%s%".',resourceMapName); end
            fprintf(fw, '%s', char(rdfXml));
            fclose(fw);
            fprintf('\nThe resource map is :\n %s \n\n', char(rdfXml)); % output to the screen
            cd(curDir);
            
            % Return the Java DataPackage as a Matlab structured array
            data_package = struct(runManager.dataPackage);
            
            % Unlock the RunManager instance
            munlock('RunManager');
            
        end
        
        function runs = listRuns(runManager, quiet, startDate, endDate, tags)
            % LISTRUNS Lists prior executions (runs) and information about them.
        end
        
        function deleted_runs = deleteRuns(runIdList, startDate, endDate, tags)
            % DELETERUNS Deletes prior executions (runs) from the stored
            % list.
            
        end
        
        function package_id = view(runManager, packageId)
            % VIEW Displays detailed information about a data package that
            % is the result of an execution (run).
            
        end
        
        function package_id = publish(runManager, packageId)
            % PUBLISH Uploads a data package produced by an execution (run)
            % to the configured DataONE Member Node server.
            
            import org.dataone.client.v2.MNode;
            import org.dataone.client.v2.itk.D1Client;
            import org.dataone.service.types.v1.NodeReference;
            
            curRunDir = [runManager.runDir filesep packageId filesep];
            fprintf('curRunDir: %s\n', curRunDir);
            if ~exist(curRunDir, 'dir')
                error([' A directory was not found for execution identifier: ' packageId]);       
            end       
            
            % Get a MNode instance to the Member Node
            try 
                % Get D1 cilogon certificate stored at /tmp/x509up_u501
                certificate = runManager.getCertificate();
                % Pull the subject DN out of the certificate for use in system metadata
                runManager.configuration.submitter = certificate.getSubjectDN();
                
                % Get D1 cilogon authToken string
                %authToken = runManager.configuration.get('authentication_token');
                %fprintf('authToken is: %s\n', authToken);
                %D1Client.setAuthToken(authToken);
            
                % Set the Node ID
                nref = NodeReference();
                nref.setValue(runManager.configuration.target_member_node_id);
                
                % Get a MNode instance to the Member Node using the Node ID
                mnNode = D1Client.getMN(nref);
                if isempty(mnNode)
                   error(['Member node' runManager.configuration.target_member_node_id 'encounted an error on the getMN() request.']); 
                end
                    
                fprintf('mn ndoe base url is: %s\n', char(mnNode.getNodeBaseServiceUrl())); 
                
                
                
                package_id = packageId; % temporary
         
            catch runtimeError 
                error(['Could not create member node reference: ' runtimeError.message]);
            end
        end  
       
        
        function certificate = getCertificate(runManager)
            % GETCERTIFICATE Gets a certificate 
            import org.dataone.client.auth.CertificateManager;
            import java.security.cert.X509Certificate;
            import java.security.PrivateKey;
            
            % Load the manager itself
            cm = CertificateManager.getInstance();
            
            % Get a certificate for the Root CA           
            certificate = CertificateManager.getInstance().loadCertificate();
            fprintf('Client subject is: %s\n', char(certificate.getSubjectDN()));
        end
        
        
        function init(runManager)
            % INIT initializes the RunManager instance
                        
            % Ensure the provenance storage directory is configured
            if ( ~ isempty(runManager.configuration) )
                prov_dir = runManager.configuration.get('provenance_storage_directory');
                
                % Only proceed if the runs directory is available
                if ( ~ exist(prov_dir, 'dir') )
                    runs_dir = fullfile(prov_dir, 'runs', filesep);
                    [status, message, message_id] = mkdir(runs_dir);
                    
                    if ( status ~= 1 )
                        error(message_id, [ 'The directory ' runs_dir ...
                              ' could not be created. The error message' ...
                              ' was: ' message]);
                    
                    elseif ( strcmp(message, 'already exists') )
                        if ( runManager.configuration.debug )
                            disp(['The directory ' runs_dir ...
                                ' already exists and will not be created.']);
                        end
                    end                    
                end
            end
        end
 
        function captureProspectiveProvenanceWithYW(runManager)
            % CAPTUREPROSPECTIVEPROVENANCEWITHYW captures the prospective
            % provenance using YesWorkflow.
            
            % Scan the script for inline YesWorkflow comments
            import java.io.BufferedReader;
            import org.yesworkflow.annotations.Annotation;
            import org.yesworkflow.model.Program;
            import org.yesworkflow.model.Workflow;
            import java.io.File;
            import java.io.FileReader;
            import java.util.List;
            import java.util.HashMap;
                       
            try
                % Read script content from disk
                script = File(runManager.execution.software_application);
                freader = FileReader(script);
                reader = BufferedReader(freader);
            
                % Call YW-Extract module
                runManager.extractor = runManager.extractor.reader(reader); 
                annotations = runManager.extractor.extract().getAnnotations();
        
                % Call YW-Model module
                runManager.modeler = runManager.modeler.annotations(annotations);
                runManager.modeler = runManager.modeler.model();
                runManager.workflow = runManager.modeler.getModel().program; 
          
                % Call YW-Graph module
                if runManager.configuration.generate_workflow_graphic
                    import org.yesworkflow.graph.GraphView;
                    import org.yesworkflow.graph.CommentVisibility;
                    import org.yesworkflow.extract.HashmapMatlabWrapper;
                    import org.yesworkflow.graph.LayoutDirection;
                
                    runManager.grapher = runManager.grapher.workflow(runManager.workflow);
                    gconfig = HashmapMatlabWrapper;
                
                    % Set the working directory to be the run metadata directory for this run
                    curDir = pwd();
                    wd = cd(runManager.runDir); 
                
                    gconfig.put('comments', CommentVisibility.HIDE);
                               
                    % Generate YW.Process_View dot file
                    runManager.processViewDotFileName = [runManager.configuration.script_base_name '_process_view.gv']; 
                    gconfig.put('view', GraphView.PROCESS_CENTRIC_VIEW);
                    gconfig.put('layout', LayoutDirection.LR);
                    gconfig.put('dotfile', runManager.processViewDotFileName);
                    runManager.grapher.configure(gconfig);              
                    runManager.grapher = runManager.grapher.graph();           
            
                    % Generate YW.Data_View dot file
                    runManager.dataViewDotFileName = [runManager.configuration.script_base_name '_data_view.gv'];
                    gconfig.put('view', GraphView.DATA_CENTRIC_VIEW);
                    gconfig.put('layout', LayoutDirection.LR);
                    gconfig.put('dotfile', runManager.dataViewDotFileName);
                    runManager.grapher.configure(gconfig);
                    runManager.grapher = runManager.grapher.graph();
            
                    % Generate YW.Combined_View dot file
                    runManager.combinedViewDotFileName = [runManager.configuration.script_base_name '_combined_view.gv'];
                    gconfig.put('view', GraphView.COMBINED_VIEW);
                    gconfig.put('layout', LayoutDirection.TB);
                    gconfig.put('dotfile', runManager.combinedViewDotFileName);                
                    runManager.grapher.configure(gconfig);
                    runManager.grapher = runManager.grapher.graph();
                
                    cd(curDir); % go back to current working directory          
                end  
                
                %% ToDo: close file open using java FileReader API
                if isempty(br) == 0  
                    br.close();
                    fprintf('close file.');
                end
            catch ME      
            end      
        end
        
    end
end
