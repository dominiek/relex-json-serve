#
# Converts a Penn Tree Structure string into a recursive array
# Note: I really suck at recursion, my apologies for this mess.
#

class PhraseTree
  
  def initialize(str)
    @str = str
  end
  
  def to_a; parse.last; end
  
  private
  
  def parse(from = 1)
    collected = []
    skip_to = nil
    from.upto(@str.size) do |i|
      if skip_to
        next unless i >= skip_to
      end
      if @str[i] == ')'[0]
        str = @str.slice(from, i-from).split("(").first
        m = str.match(/^([A-Z]+) .*/)
        p = {:pos => m[1], :phrase => str.slice(m[1].size+1, str.size)}
        collected << p
        return [i+1, collected]
      end
      if @str[i] == '('[0]
        skip_to, c = parse(i+1)
        collected << c
      end
    end
  end
  
end
