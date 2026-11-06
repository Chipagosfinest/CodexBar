import re,unicodedata

def named_meter_pairs(title, accessibility):
    fields=[re.sub(r'\s+',' ',unicodedata.normalize('NFKC',v)).casefold() for v in [title,accessibility]]
    t=r'(?<![a-z])(?:total|t)\s*(\d+(?:\.\d+)?)\s*%'
    gb=r'(?<![a-z])(?:grok\s*bot|gb)\s*(\d+(?:\.\d+)?)\s*%'
    values=[(re.findall(t,v),re.findall(gb,v)) for v in fields]
    return (any(a and b for a,b in values) and
            all(float(x)==20 for a,_ in values for x in a) and
            all(float(x)==80 for _,b in values for x in b))

def guard_controls():
    assert named_meter_pairs('T20% GB80%','')
    assert named_meter_pairs('','Total 20% used, Grok Bot 80% used')
    assert not named_meter_pairs('T80% GB20%','')
    assert not named_meter_pairs('20% 80%','')
    assert not named_meter_pairs('T20% GB80%','Total80% Grok Bot20%')
    assert not named_meter_pairs('T20%','')
    return {'controlsPassed':True,'cases':['shortNamedPairs','accessibleNamedPairs','swappedRejected','unnamedRejected','contradictoryAccessibilityRejected','missingBotRejected']}
