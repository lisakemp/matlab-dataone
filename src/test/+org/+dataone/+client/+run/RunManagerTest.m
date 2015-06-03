% RUNMANAGERTEST A class used to test the org.dataone.client.run.RunManager class functionality
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

classdef RunManagerTest < matlab.unittest.TestCase
    
    properties 
        filename
        testDir
    end

    methods (TestMethodSetup)
        
        function setUp(testCase)
            % SETUP Set up the test environment
            %testCase.filename = 'test/resources/DroughtTimeScale_Markup_v2.m';
            testCase.filename = 'test/resources/C3_C4_map_present_NA_Markup_v2.m';
            testCase.testDir = 'test/resources';
        end
    end
    
    methods (TestMethodTeardown)
        
        function tearDown(testCase)
            % TEARDOWN Tear down the test environment
            
        end
    end
    
    methods (Test)
        
        function testGetInstanceNoConfiguration(testCase)
            % TESTGETINSTANCENOCONFIGURATION tests calling the getInstance()
            % function without passing a Configuration object

            import org.dataone.client.run.RunManager;
            
            disp('In testGetInstanceNoConfiguration() ...');
            
            mgr = RunManager.getInstance();
            old_format_id = get(mgr.configuration, 'format_id');
            set(mgr.configuration, 'format_id', 'application/octet-stream');
            assertInstanceOf(testCase, mgr, 'org.dataone.client.run.RunManager');
            % Test a single default property to ensure the configuration was set
            assertEqual(testCase, mgr.configuration.format_id, 'application/octet-stream');
            
            % reset to the original
            set(mgr.configuration, 'format_id', old_format_id);

        end
        
        
        function testPublish(testCase)
            import org.dataone.client.run.RunManager;
            import org.dataone.client.configure.Configuration;
            
            disp('In testPublish() ...');
            configuration = Configuration();
            
            mgr = RunManager.getInstance(configuration);
            set(mgr.configuration, 'target_member_node_id', 'urn:node:mnDemo2');
        end
        
        
        function testGetInstanceWithConfiguration(testCase)
            % TESTGETINSTANCENOCONFIGURATION tests calling the getInstance()
            % function while passing a Configuration object

            import org.dataone.client.run.RunManager;
            import org.dataone.client.configure.Configuration;
            
            disp('In testGetInstanceWithConfiguration() ...');
             
            configuration = Configuration();
            
            mgr = RunManager.getInstance(configuration);
            old_format_id = get(mgr.configuration, 'format_id');
            set(mgr.configuration, 'format_id', 'text/csv');
            
            % Test the instance type
            assertInstanceOf(testCase, mgr, 'org.dataone.client.run.RunManager');
            % Test a single preset property
            assertEqual(testCase, mgr.configuration.format_id, 'text/csv');
            
            % reset to the original
            set(mgr.configuration, 'format_id', old_format_id);

            %% Test for YesWorkflow              
            script_path = fullfile(pwd(), filesep, testCase.filename); 
            fprintf('current script path: %s\n', script_path);
            
            mgr.configuration.provenance_storage_directory = testCase.testDir;
            
            mgr.configuration.script_base_name = ''; % A user can give a prefix name to output files; otherwise, the script name will be used as prefix name.
            
            mgr.record(script_path, '');
        
            if mgr.configuration.include_workflow_graphic
                curDir = pwd();
                cd(mgr.runDir); % go to the provenance run directory
                
                % Display 3 different views of YesWorkflow output files
                %system('/usr/bin/open process_view.pdf');
                %system('/usr/bin/open data_view.pdf');
                %system('/usr/bin/open combined_view.pdf');
                
                cd(curDir);
            end
            
            % Access a matlab script and run it
            %DroughtTimeScale_Markup_v2;
            %y = textreadFile('ywModelFacts.pl');
            %fprintf('%s', char(y));
            
        end
        


    end
end