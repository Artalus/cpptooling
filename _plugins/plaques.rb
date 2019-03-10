
class CppPlaqueInlineTag < Liquid::Tag
    def initialize(tag_name, msg, input, tokens)
        @tag_name = tag_name
        @msg = msg
        super(tag_name, input, tokens)
    end
    def render(context)
        output =  "<div class=\"#{@tag_name}\"><h5>#{@msg}</h5><p>"
        return output;
    end
end

class EndCppPlaqueInlineTag < Liquid::Tag
    def initialize(tag_name, input, tokens)
        super
    end
    def render(context)
        output =  "</p></div>"
        return output;
    end
end

class TldrInlineTag < CppPlaqueInlineTag
    def initialize(tag_name, input, tokens)
        super("tldr", "TL;DR", input, tokens)
    end
end

class NoteInlineTag < CppPlaqueInlineTag
    def initialize(tag_name, input, tokens)
        super("note", "Note", input, tokens)
    end
end

def register_tag(tag, clazz)
    Liquid::Template.register_tag(tag, clazz)
    Liquid::Template.register_tag('end'+tag, EndCppPlaqueInlineTag)
end


register_tag('tldr', TldrInlineTag)
register_tag('note', NoteInlineTag)
