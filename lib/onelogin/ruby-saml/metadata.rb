require "rexml/document"
require "rexml/xpath"
require "uri"

require "onelogin/ruby-saml/logging"

# Class to return SP metadata based on the settings requested.
# Return this XML in a controller, then give that URL to the the
# IdP administrator.  The IdP will poll the URL and your settings
# will be updated automatically
module OneLogin
  module RubySaml
    include REXML
    class Metadata
      def generate(settings)
        meta_doc = REXML::Document.new
        root = meta_doc.add_element "md:EntityDescriptor", {
            "xmlns:md" => "urn:oasis:names:tc:SAML:2.0:metadata"
        }
        sp_sso = root.add_element "md:SPSSODescriptor", {
            "protocolSupportEnumeration" => "urn:oasis:names:tc:SAML:2.0:protocol",
            # Metadata request need not be signed (as we don't publish our cert)
            "AuthnRequestsSigned" => false,
            # However we would like assertions signed if idp_cert_fingerprint or idp_cert is set
            "WantAssertionsSigned" => (!settings.idp_cert_fingerprint.nil? || !settings.idp_cert.nil?)
        }
        if settings.issuer != nil
          root.attributes["entityID"] = settings.issuer
        end
        if settings.assertion_consumer_logout_service_url != nil
          sp_sso.add_element "md:SingleLogoutService", {
              # Add this as a setting to create different bindings?
              "Binding" => "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect",
              "Location" => settings.assertion_consumer_logout_service_url,
              "ResponseLocation" => settings.assertion_consumer_logout_service_url,
              "isDefault" => true,
              "index" => 0
          }
        end
        if settings.name_identifier_format != nil
          name_id = sp_sso.add_element "md:NameIDFormat"
          name_id.text = settings.name_identifier_format
        end
        if settings.assertion_consumer_service_url != nil
          sp_sso.add_element "md:AssertionConsumerService", {
              # Add this as a setting to create different bindings?
              "Binding" => "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST",
              "Location" => settings.assertion_consumer_service_url,
              "isDefault" => true,
              "index" => 0
          }
        end

        if settings.attribute_consuming_service.configured?
          sp_acs = sp_sso.add_element "md:AttributeConsumingService", {
            "isDefault" => "true",
            "index" => settings.attribute_consuming_service.index 
          }
          srv_name = sp_acs.add_element "md:ServiceName", {
            "xml:lang" => "en"
          }
          srv_name.text = settings.attribute_consuming_service.name
          settings.attribute_consuming_service.attributes.each do |attribute|
            sp_req_attr = sp_acs.add_element "md:RequestedAttribute", {
              "NameFormat" => attribute[:name_format],
              "Name" => attribute[:name], 
              "FriendlyName" => attribute[:friendly_name]
            }
            unless attribute[:attribute_value].nil?
              sp_attr_val = sp_req_attr.add_element "md:AttributeValue"
              sp_attr_val.text = attribute[:attribute_value]
            end
          end
        end

        # With OpenSSO, it might be required to also include
        #  <md:RoleDescriptor xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:query="urn:oasis:names:tc:SAML:metadata:ext:query" xsi:type="query:AttributeQueryDescriptorType" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol"/>
        #  <md:XACMLAuthzDecisionQueryDescriptor WantAssertionsSigned="false" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol"/>

        meta_doc << REXML::XMLDecl.new("1.0", "UTF-8")
        ret = ""
        # pretty print the XML so IdP administrators can easily see what the SP supports
        meta_doc.write(ret, 1)

        return ret
      end
    end
  end
end
