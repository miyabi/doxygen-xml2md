require 'rexml/document'

def parseElement(element, decorate=true)
	emphasis = ''
	if decorate then
		emphasis = '*'
	end

	text = element.to_s.gsub(/^<(\w+)[^>]*>(.+)<\/\1>$/, '\2')
	text = text.gsub(/<(ref)[^>]*>([^<]+)<\/\1>/, "#{emphasis}\\2#{emphasis}")
	text = text.gsub(/<(emphasis)>([^<]+)<\/\1>/, "#{emphasis}\\2#{emphasis}")
	text = text.gsub(/<(computeroutput)>([^<]+)<\/\1>/, "`\\2`")
	print text
end

def parseParas(paras, combine=false)
	count = 0
	paras.elements.each('para') { |para|
		if count >= 1 and combine != false then
			print combine
		end
		parseElement(para)
		if combine == false then
			print "\n"
		end
		count += 1
	}
	if count >= 1 and combine == false then
		print "\n"
	end
end

def parseSimpeSect(simplesect)
	kind = simplesect.attribute('kind').to_s
	if kind == 'return' then
		print "#### Returns\n\n"
	else
		return
	end

	if simplesect.has_elements? then
		print "-\t"
		parseParas(simplesect)
		print "\n"
	end
end

def parseParameterList(parameterlist)
	kind = parameterlist.attribute('kind').to_s
	if kind == 'param' then
		print "#### Parameters\n\n"
	else
		return
	end

	count = 0
	parameterlist.elements.each('parameteritem') { |parameteritem|
		if not parameteritem.elements['parameternamelist'].has_elements? then
			next
		end

		print "-\t"
		parameteritem.elements.each_with_index('parameternamelist/parametername') { |parametername, i|
			if i >= 1 then print " " end
			print "*#{parametername.text}*"
		}
		if parameteritem.elements['parameterdescription'].has_elements? then
			print " - "
			parseParas(parameteritem.elements['parameterdescription'], ' ')
		end
		print "\n"
		count += 1
	}

	if count >= 1 then
		print "\n"
	end
end

def parseDetailedDescription(detaileddescription)
	detaileddescription.elements.each('para') { |para|
		para.elements.each() { |element|
			if element.name == 'simplesect' then
				parseSimpeSect(element)
			elsif element.name == 'parameterlist' then
				parseParameterList(element)
			end
		}
	}
end

def parseEnum(memberdef)
	print "### enum #{COMPOUND_NAME}.#{memberdef.elements['name'].text}\n\n"
	parseParas(memberdef.elements['briefdescription'])
	if memberdef.elements['enumvalue'].has_elements? then
		print "|Enumerator|   |\n"
		print "|---|---|\n"
		memberdef.elements.each('enumvalue') { |enumvalue|
			print "|#{enumvalue.elements['name'].text}|"
			parseParas(enumvalue.elements['briefdescription'], '<br>')
			print "|\n"
		}
		print "\n"
	end
end

def parseProperty(memberdef)
	print "### "
	parseElement(memberdef.elements['type'], false)
	print " #{memberdef.elements['name'].text}\n\n"

	attributes = []
	if memberdef.attribute('static').to_s == 'yes' then
		attributes += ['`static`']
	end
	if memberdef.attribute('gettable').to_s == 'yes' then
		attributes += ['`get`']
	end
	if memberdef.attribute('settable').to_s == 'yes' then
		attributes += ['`set`']
	end
	if attributes.length >= 1 then
		print attributes.join(' ') + "\n\n"
	end

	parseParas(memberdef.elements['briefdescription'])
	parseParas(memberdef.elements['detaileddescription'])
end

def parseVariable(memberdef)
	print "### "
	parseElement(memberdef.elements['type'], false)
	print " #{memberdef.elements['name'].text}\n\n"
	parseParas(memberdef.elements['briefdescription'])
end

def parseFunction(memberdef)
	print "### "
	parseElement(memberdef.elements['type'], false)
	print " #{memberdef.elements['name'].text} #{memberdef.elements['argsstring'].text}\n\n"
	parseParas(memberdef.elements['briefdescription'])
	parseDetailedDescription(memberdef.elements['detaileddescription'])
end

def parseMember(memberdef)
	kind = memberdef.attribute('kind').to_s
	if kind == 'enum' then
		parseEnum(memberdef)
	elsif kind == 'property' then
		parseProperty(memberdef)
	elsif kind == 'variable' then
		parseVariable(memberdef)
	elsif kind == 'function' then
		parseFunction(memberdef)
	end
end

def parseSection(sectiondef)
	kind = sectiondef.attribute('kind').to_s
	if kind == 'public-type' then
		print "## Public Types\n\n"
	elsif kind == 'property' then
		print "## Properties\n\n"
	elsif kind == 'public-attrib' then
		print "## Public Attributes\n\n"
	elsif kind == 'public-func' then
		print "## Public Member Functions\n\n"
	else
		return
	end
	sectiondef.elements.each('memberdef') { |memberdef|
		parseMember(memberdef)
	}
	print "---\n\n"
end

def parseCompound(compounddef)
	print "# #{compounddef.elements['compoundname'].text} Class Reference\n\n"
	parseParas(compounddef.elements['briefdescription'])

	sectiondefs = []
	sectiondefs += [compounddef.elements['sectiondef[@kind="public-type"]']]
	sectiondefs += [compounddef.elements['sectiondef[@kind="property"]']]
	sectiondefs += [compounddef.elements['sectiondef[@kind="public-attrib"]']]
	sectiondefs += [compounddef.elements['sectiondef[@kind="public-func"]']]

	sectiondefs.each { |sectiondef|
		parseSection(sectiondef)
	}
end

if ARGV.length < 1 then
	puts 'Usage: doxygen-xml2md.rb <Input file> [<Output file>]'
	exit
end

input_file = ARGV[0]
output_file = ''

if ARGV.length >= 2 then
	output_file = ARGV[1]
end

if output_file.length >= 1 then
	$stdout = open(output_file, 'w')
end

document = REXML::Document.new(open(input_file))
COMPOUND_NAME = document.elements['doxygen/compounddef/compoundname'].text

parseCompound(document.elements['doxygen/compounddef'])

$stdout = STDOUT
