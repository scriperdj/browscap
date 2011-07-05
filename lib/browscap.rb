# Browscap Ruby Gem - A simple library to parse the beloved browscap.ini file.
# Copyright (C) 2010
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Original python code by Henning Schroeder
# Ported to Ruby by Lukas Fittl
#

require 'inifile'

class Browscap
  def initialize(filename = File.join(File.dirname(__FILE__), '..', 'ini', 'default.ini'))
    @@user_agent_properties ||= {}
    @@user_agent_regexps ||= {}
    @@match_cache ||= {}

    if @@user_agent_properties.empty? || @@user_agent_regexps.empty?
      ini = IniFile.load(filename)

      # Remote meta sections
      ini.delete_section '*'
      ini.delete_section 'GJK_Browscap_Version'

      # Create a list of non-parent sections
      child_sections = ini.sections.dup
      ini.sections.each do |section|
        child_sections.delete ini[section]["Parent"]
      end

      # Populate user_agent_properties and user_agent_regexps
      child_sections.each do |section|
        properties = get_browser_props(ini, section)

        browser = Browser.new
        browser.browser = properties['Browser']
        browser.version = properties['Version']
        browser.major_ver = properties['MajorVer'].to_i
        browser.minor_ver = properties['MinorVer'].to_i
        browser.platform = properties['Platform']
        browser.alpha = properties['Alpha'].downcase == 'true'
        browser.beta = properties['Beta'].downcase == 'true'
        browser.win16 = properties['Win16'].downcase == 'true'
        browser.win32 = properties['Win32'].downcase == 'true'
        browser.win64 = properties['Win64'].downcase == 'true'
        browser.frames = properties['Frames'].downcase == 'true'
        browser.iframes = properties['IFrames'].downcase == 'true'
        browser.tables = properties['Tables'].downcase == 'true'
        browser.cookies = properties['Cookies'].downcase == 'true'
        browser.background_sounds = properties['BackgroundSounds'].downcase == 'true'
        browser.javascript = properties['JavaScript'].downcase == 'true'
        browser.vbscript = properties['VBScript'].downcase == 'true'
        browser.java_applets = properties['JavaApplets'].downcase == 'true'
        browser.activex_controls = properties['ActiveXControls'].downcase == 'true'
        browser.is_banned = properties['isBanned'].downcase == 'true'
        browser.is_mobile_device = properties['isMobileDevice'].downcase == 'true'
        browser.is_syndication_reader = properties['isSyndicationReader'].downcase == 'true'
        browser.crawler = properties['Crawler'].downcase == 'true'
        browser.css_version = properties['CssVersion'].to_i
        browser.aol_version = properties['aolVersion'].to_i

        @@user_agent_properties[section] = browser

        # Convert .ini file regexp syntax into ruby regexp syntax
        regexp = section.dup
        regexp.gsub! /([\^\$\(\)\[\]\.\-])/, "\\\\\\1"
        regexp.gsub! "?", "."
        regexp.gsub! "*", ".*?"

        @@user_agent_regexps[section] = Regexp.new("^%s$" % regexp)
      end
    end
  end

  # Looks up the given user agent string and returns a dictionary containing information on this browser or bot.
  def query(user_agent)
    section = match(user_agent)
    @@user_agent_properties[section]
  end
  alias =~ query

  protected

  def match(user_agent)
    return @@match_cache[user_agent] if @@match_cache[user_agent]

    matching_section = ''

    @@user_agent_regexps.each do |section, regexp|
      # Find the longest regexp that matches the given user_agent_string. The length check is needed since multiple reg-exps may match the user_agent_string.
      if regexp.match(user_agent) && section.length > matching_section.length
        matching_section = section
      end
    end

    @@match_cache[user_agent] = matching_section
    matching_section
  end

  # Recursively traverses the properties tree (based on 'parent' attribute of each section) and
  # returns a dictionary of all browser properties for the given section name. The properties lower
  # in the tree override those higher in the tree.
  def get_browser_props(ini, section)
    data = {}

    if parent = ini[section]["Parent"]
      data.merge! get_browser_props(ini, parent)
    end

    data.merge! ini[section]
    data
  end
end

class Browser
  attr_accessor :activex_controls, :alpha, :aol_version, :background_sounds, :beta,
    :browser, :cookies, :crawler, :css_version, :frames, :iframes, :is_banned, :is_mobile_device,
    :is_syndication_reader, :java_applets, :javascript, :major_ver, :minor_ver, :platform,
    :css_version, :tables, :vbscript, :version, :win16, :win32, :win64

  [
    :activex_controls, :alpha, :aol_version, :background_sounds, :beta, :cookies, :crawler, :frames,
    :iframes, :is_banned, :is_mobile_device, :is_syndication_reader, :java_applets, :javascript,
    :css_version, :tables, :vbscript, :win16, :win32, :win64
  ].each do |method_name|
    class_eval %{
      def #{method_name}?
        @#{method_name}
      end
    }
  end
end