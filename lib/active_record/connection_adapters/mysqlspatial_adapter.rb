# -----------------------------------------------------------------------------
# 
# MysqlSpatial adapter for ActiveRecord
# 
# -----------------------------------------------------------------------------
# Copyright 2010 Daniel Azuma
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# -----------------------------------------------------------------------------
;


require 'rgeo/active_record'
require 'active_record/connection_adapters/mysql_adapter'


# :stopdoc:

module Arel
  module Visitors
    
    class MySQLSpatial < MySQL
      
      FUNC_MAP = {
        'ST_WKTToSQL' => 'GeomFromText',
        'ST_Equals' => 'Equals',
      }
      
      include ::RGeo::ActiveRecord::SpatialToSql
      
      def st_func(standard_name_)
        FUNC_MAP[standard_name_] || standard_name_
      end
      
    end
    
    VISITORS['mysqlspatial'] = ::Arel::Visitors::MySQLSpatial
    
  end
end

# :startdoc:


# The activerecord-mysqlspatial-adapter gem installs the *mysqlspatial*
# connection adapter into ActiveRecord.

module ActiveRecord
  
  
  # ActiveRecord looks for the mysqlspatial_connection factory method in
  # this class.
  
  class Base
    
    
    # Create a mysqlspatial connection adapter.
    
    def self.mysqlspatial_connection(config_)
      unless defined?(::Mysql)
        begin
          require 'mysql'
        rescue ::LoadError
          raise "!!! Missing the mysql gem. Add it to your Gemfile: gem 'mysql'"
        end
        unless defined?(::Mysql::Result) && ::Mysql::Result.method_defined?(:each_hash)
          raise "!!! Outdated mysql gem. Upgrade to 2.8.1 or later. In your Gemfile: gem 'mysql', '2.8.1'. Or use gem 'mysql2'"
        end
      end
      config_ = config_.symbolize_keys
      mysql_ = ::Mysql.init
      mysql_.ssl_set(config_[:sslkey], config_[:sslcert], config_[:sslca], config_[:sslcapath], config_[:sslcipher]) if config_[:sslca] || config_[:sslkey]
      default_flags_ = ::Mysql.const_defined?(:CLIENT_MULTI_RESULTS) ? ::Mysql::CLIENT_MULTI_RESULTS : 0
      default_flags_ |= ::Mysql::CLIENT_FOUND_ROWS if ::Mysql.const_defined?(:CLIENT_FOUND_ROWS)
      options_ = [config_[:host], config_[:username] ? config_[:username].to_s : 'root', config_[:password].to_s, config_[:database], config_[:port], config_[:socket], default_flags_]
      ConnectionAdapters::MysqlSpatialAdapter.new(mysql_, logger, options_, config_)
    end
    
    
  end
  
  
  module ConnectionAdapters  # :nodoc:
    
    class MysqlSpatialAdapter < MysqlAdapter  # :nodoc:
      
      
      ADAPTER_NAME = 'MysqlSpatial'.freeze
      
      NATIVE_DATABASE_TYPES = MysqlAdapter::NATIVE_DATABASE_TYPES.merge(:geometry => {:name => "geometry"}, :point => {:name => "point"}, :line_string => {:name => "linestring"}, :polygon => {:name => "polygon"}, :geometry_collection => {:name => "geometrycollection"}, :multi_point => {:name => "multipoint"}, :multi_line_string => {:name => "multilinestring"}, :multi_polygon => {:name => "multipolygon"})
      
      
      def native_database_types
        NATIVE_DATABASE_TYPES
      end
      
      
      def adapter_name
        ADAPTER_NAME
      end
      
      
      def quote(value_, column_=nil)
        if ::RGeo::Feature::Geometry.check_type(value_)
          "GeomFromWKB(0x#{::RGeo::WKRep::WKBGenerator.new(:hex_format => true).generate(value_)},#{value_.srid})"
        else
          super
        end
      end
      
      
      def add_index(table_name_, column_name_, options_={})
        if options_[:spatial]
          index_name_ = index_name(table_name_, :column => Array(column_name_))
          if ::Hash === options_
            index_name_ = options_[:name] || index_name_
          end
          execute "CREATE SPATIAL INDEX #{index_name_} ON #{table_name_} (#{Array(column_name_).join(", ")})"
        else
          super
        end
      end
      
      
      def columns(table_name_, name_=nil)
        result_ = execute("SHOW FIELDS FROM #{quote_table_name(table_name_)}", :skip_logging)
        columns_ = []
        result_.each do |field_|
          columns_ << SpatialColumn.new(field_[0], field_[4], field_[1], field_[2] == "YES")
        end
        result_.free
        columns_
      end
      
      
      def indexes(table_name_, name_=nil)
        indexes_ = []
        current_index_ = nil
        result_ = execute("SHOW KEYS FROM #{quote_table_name(table_name_)}", name_)
        result_.each do |row_|
          if current_index_ != row_[2]
            next if row_[2] == "PRIMARY" # skip the primary key
            current_index_ = row_[2]
            indexes_ << ::RGeo::ActiveRecord::SpatialIndexDefinition.new(row_[0], row_[2], row_[1] == "0", [], [], row_[10] == 'SPATIAL')
          end
          indexes_.last.columns << row_[4]
          indexes_.last.lengths << row_[7]
        end
        result_.free
        indexes_
      end
      
      
      class SpatialColumn < ConnectionAdapters::MysqlColumn  # :nodoc:
        
        
        def initialize(name_, default_, sql_type_=nil, null_=true)
          super(name_, default_,sql_type_, null_)
          @geometric_type = ::RGeo::ActiveRecord.geometric_type_from_name(sql_type_)
          @ar_class = ::ActiveRecord::Base
        end
        
        
        def set_ar_class(val_)
          @ar_class = val_
        end
        
        
        attr_reader :geometric_type
        
        
        def spatial?
          type == :geometry
        end
        
        
        def klass
          type == :geometry ? ::RGeo::Feature::Geometry : super
        end
        
        
        def type_cast(value_)
          type == :geometry ? SpatialColumn.convert_to_geometry(value_, @ar_class, name) : super
        end
        
        
        def type_cast_code(var_name_)
          type == :geometry ? "::ActiveRecord::ConnectionAdapters::MysqlSpatialAdapter::SpatialColumn.convert_to_geometry(#{var_name_}, self.class, #{name.inspect})" : super
        end
        
        
        private
        
        def simplified_type(sql_type_)
          sql_type_ =~ /geometry|point|linestring|polygon/i ? :geometry : super
        end
        
        
        def self.convert_to_geometry(input_, ar_class_, column_)
          case input_
          when ::RGeo::Feature::Geometry
            factory_ = ar_class_.rgeo_factory_for_column(column_, :srid => input_.srid)
            ::RGeo::Feature.cast(input_, factory_)
          when ::String
            marker_ = input_[4,1]
            if marker_ == "\x00" || marker_ == "\x01"
              factory_ = ar_class_.rgeo_factory_for_column(column_, :srid => input_[0,4].unpack(marker_ == "\x01" ? 'V' : 'N').first)
              ::RGeo::WKRep::WKBParser.new(factory_).parse(input_[4..-1])
            else
              factory_ = ar_class_.rgeo_factory_for_column(column_)
              ::RGeo::WKRep::WKTParser.new(factory_, :support_ewkt => true).parse(input_)
            end
          else
            nil
          end
        end
        
        
      end
      
      
    end
    
  end
  
  
end
