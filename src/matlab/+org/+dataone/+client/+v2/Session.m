% SESSION A class that provides an authenticated session based on configuration settings
%   The Session class uses configuration settings to provide credentials
%   when making requests to Member Nodes and Coordinating Nodes.  It uses
%   the either the Configuration.authentication_token property or the
%   Configuration.certificate_path property to create a Session object.
%
% This work was created by participants in the DataONE project, and is
% jointly copyrighted by participating institutions in DataONE. For
% more information on DataONE, see our web site at http://dataone.org.
%
%   Copyright 2009-2016 DataONE
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

classdef Session < hgsetget
    
    properties (Access = 'private')
        
        % The underlying Java Session
        j_session;

    end
    
    properties
        
        % The account subject string from the authentication token or certificate
        account_subject;
        
        % The expiration date and time of the authentication token or certificate
        expiration;
               
        % The type of session (authentication token or X509 certificate)
        session_type;
        
        
    end

    methods
        
        function session = Session()
            % SESSION Constructs a Session object using Configuration settings
            
            import org.dataone.client.auth.CertificateManager;
            import java.security.cert.X509Certificate;
            import org.dataone.client.configure.Configuration;
            import com.nimbusds.jose.JWSObject;
            
            session.j_session = org.dataone.service.types.v1.Session(); 
            
            % Get an authentication token or X509 certificate
            config = Configuration.loadConfig('');
            auth_token = config.get('authentication_token');
            cert_path = config.get('certificate_path');
            
            % Use auth tokens preferentially
            if ( ~isempty(auth_token) )
                import org.dataone.client.auth.AuthTokenSession;
                
                % Parse the token to get critical properties
                try
                    jwt = JWSObject.parse(java.lang.String(auth_token));
                    token_properties = ...
                        loadjson(char(jwt.getPayload().toString()));
                    session.account_subject = token_properties.userId;
                    expires = ...
                        addtodate( ...
                            datenum( ...
                                datetime( ...
                                    token_properties.issuedAt, ...
                                    'TimeZone', 'UTC', ...
                                    'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSZ' ...
                                ) ...
                            ), token_properties.ttl, 'millisecond');
                        
                    session.expiration = ...
                        datestr(expires, 'yyyy-MM-dd HH:mm z');
                    
                    session.session_type = 'authentication token';
                    
                catch parseException
                    disp('There was a problem parsing the authentication token: ');
                    
                    rethrow(parseException);
                    
                end
                j_session = AuthTokenSession(auth_token);
                
            % Otherwise use the X509 certificate
            elseif ( ~ isempty(cert_path) )
                CertificateManager.getInstance().setCertificateLocation(cert_path);
                cert = CertificateManager.getInstance().loadCertificate();
                formatter = java.text.SimpleDateFormat('yyyy-MM-dd HH:MM z');
                session.expiration = char( ...
                    formatter.format(cert.getNotAfter()));
                
                session.session_type = 'X509 certificate';
                
                subjectDN = CertificateManager.getInstance().getSubjectDN(cert);
                session.account_subject = char( ...
                    CertificateManager.getInstance().standardizeDN( ...
                    subjectDN));
                
            end
        end
        
        function is_valid = isValid(self)
            % ISVALID returns true if the session has not expired
            
            is_valid = false;
            
            % Compare the current time with the expiration date
            current_datetime = datetime('now', 'TimeZone', 'UTC');
            
            expiry_datetime = datetime(self.expiration, ...
                'TimeZone', 'local', 'InputFormat', 'yyyy-MM-dd HH:mm z');
            
            if ( current_datetime < expiry_datetime)
                is_valid = true;
                
            end
        end
        
        function j_session = getJavaSession(self)
            % GETJAVASESSION returns the underlying Java Session object
            
            j_session = self.j_session;
            
        end
    end
end