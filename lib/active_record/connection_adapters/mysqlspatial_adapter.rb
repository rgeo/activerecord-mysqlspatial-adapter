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
      ::ActiveRecord::ConnectionAdapters::MysqlSpatialAdapter::MainAdapter.new(mysql_, logger, options_, config_)
    end


  end


  # All ActiveRecord adapters go in this namespace.
  module ConnectionAdapters

    # The MysqlSpatial adapter
    module MysqlSpatialAdapter

      # The name returned by the adapter_name method of this adapter.
      ADAPTER_NAME = 'MysqlSpatial'.freeze

    end

  end


end


require 'active_record/connection_adapters/mysqlspatial_adapter/version.rb'
require 'active_record/connection_adapters/mysqlspatial_adapter/main_adapter.rb'
require 'active_record/connection_adapters/mysqlspatial_adapter/spatial_column.rb'
require 'active_record/connection_adapters/mysqlspatial_adapter/arel_tosql.rb'
