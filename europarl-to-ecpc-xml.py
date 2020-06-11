#!/usr/bin/python3

import argparse
import mmap
import os
import re
import sys
from pathlib import Path
from pprint import pformat


all_speakers = set()

valid_langs = ['BG', 'CS', 'DA', 'DE', 'EL', 'EN', 'ES', 'ET', 'FI', 'FR',
               'GA', 'HU', 'IT', 'LT', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO',
               'SK', 'SL', 'SV']


class Document():

    def __init__(self, original_filename, language, use_new_filename=False, interventions=[]):
        self.original_filename = original_filename
        self.interventions = interventions
        self.language = ''
        if use_new_filename:
            self.modify_filename()
        else:
            self.filename = self.original_filename

    def modify_filename(self):
        self.filename = self.original_filename


class Speaker():

    def __init__(self, name, affiliation=None, possible_affiliation=None):
        self.name = self.correct_name(name)
        self.affiliation = affiliation
        self.possible_affiliation = possible_affiliation

    def __repr__(self):
        return pformat(dict(vars(self)), width=150)

    @staticmethod
    def correct_name(s):
        n = s
        n = n.lstrip().rstrip(' ,,-')
        n = re.sub(r'\s+', ' ', n)
        n = n.replace('–', '-')
        n = n.replace(u'\\\\xad', '-')  # FIXME
        n = n.replace(u'\\\\xa0', ' ')  # FIXME
        n = n.replace(' the ', ' The ')
        n = n.replace(' of ', ' Of ')
        n = n.replace('?ratsa', 'Kratsa')
        n = n.replace('?sagaropoulou', 'Tsagaropoulou')
        n = n.replace('Ôsagaropoulou', 'Tsagaropoulou')
        n = n.replace('S<nchez', 'Sánchez')
        n = n.replace('?aramanou', 'Karamanou')
        n = n.replace('Êaramanou', 'Karamanou')
        n = n.replace('I Böhm', 'i Böhm')
        n = n.replace('y Böhm', 'i Böhm')
        n = n.replace('Α', 'A')
        n = n.replace('τ', 'T')
        n = n.replace(', Member of the Commission', '')
        n = n.replace('Ioan', 'Ioana')
        n = n.replace('Dalai-Lama', '14th Dalai Lama')
        n = n.replace('Bethel', 'Bethell')
        n = n.replace('MADL', 'Mádl')
        n = n.replace('Und', 'und')
        n = re.sub(r'.*Vidal-Quadras.*', 'Alejo Vidal-Quadras Roca', n)
        return n


class Intervention():

    valid_affiliations = ['ALDE', 'ERA', 'EPP-ED', 'G/EFA', 'V', 'UEN', 'EDD',
                          'ELDR', 'PES', 'EUL/NGL', 'I-EN', 'IND/DEM', 'NI',
                          'TGI', 'UFE', 'S&D', 'ECR', 'EFD', 'ITS']

    def __init__(self, s):
        self.speakers = set()
        self.language = None
        self.possible_language = None
        self.speech_id = None
        self.data = ''

        self.s = s.strip()

        self.parse_speaker()
        self.parse_names()
        self.parse_affiliation()
        self.parse_language()

    def __repr__(self):
        return pformat(dict(vars(self)), width=150)

    def add_data(self, d):
        data = d
        data = re.sub(r'\s+', ' ', data)
        data = data.replace('[amp]', '&')
        data = data.replace('[...]', '')
        data = data.replace('[…]', '')
        data = data.replace('…', ' ')
        data = data.replace('...', ' ')
        data = re.sub(r'\[Article[^\]*]\]', '', data)
        data = re.sub(r'\[[^\]]*\/[^\]]*\]', '', data)
        data = data.replace('()', '')
        data = data.replace('[]', '')
        data = data.replace('[?]', '')
        self.data += data.replace('<P>', '')

    def finalize(self):
        self.data = self.data.lstrip('. ').rstrip()
        self.data = self.data.replace(' . ', '. ')
        self.data = re.sub(r'([\.\?\!\,]) +', '\g<1> ', self.data)
        self.data = re.sub(r' +', ' ', self.data)
        self.replace_english_phrases()
        if not self.language:
            self.language = 'UNKNOWN'
        for speaker in self.speakers:
            if not speaker.affiliation:
                speaker.affiliation = 'UNKNOWN'
            all_speakers.add(speaker)

    def parse_speaker(self):
        match = re.match(r'<.*SPEAKER ID="*([0-9]+)"* .*', self.s)
        if match:
            self.speech_id = match.group(1)
            print(f'speech_id: {self.speech_id}')
        else:
            print(f'speech_id not found: {self.s}')

    def parse_names(self):
        match = re.match(r'<.*NAME="(.*?)".*>', self.s)
        if not match:
            print(f'name not found: {self.s}')
            return
        print(self.s)
        names = match.group(1)
        names = self.remove_non_names(names)
        names = self.split_names(names)
        print(f'names: {names}')
        if not names:
            return
        if len(names) == 1:
            print(f'names1: {names}')
            if self.contains_conjunction(names):
                # case where only one name is found but it contains a conjunction
                print(f'case: [1] one name element found with conjunction "{self.s}"')
                names = self.replace_conjunctions(names[0])
                names = self.split_names(names)
                speaker1 = self.create_speaker_from_name(names[0])
                speaker2 = self.create_speaker_from_name(names[1])
                if speaker2.possible_affiliation and not speaker1.possible_affiliation:
                    speaker1.possible_affiliation = speaker2.possible_affiliation
                self.add_speaker(speaker1)
                self.add_speaker(speaker2)
            else:
                # case where only one name is found, just create a speaker
                print(f'case: [2] only one name element found "{self.s}"')
                speaker = self.create_speaker_from_name(names[0])
                self.add_speaker(speaker)
            return
        if len(names) == 2:
            print(f'names2: {names}')
            amatch = re.match(r'\((.*)\)', names[1])
            if amatch:
                # case where the second element is the affiliation only
                print(f'case: [3] 2nd element contains an affiliation only "{self.s}"')
                possible_affiliation = amatch.group(1)
                possible_affiliation = self.process_affiliation(possible_affiliation)
                if possible_affiliation:
                    speaker = Speaker(names[0], possible_affiliation=possible_affiliation)
                    self.add_speaker(speaker)
                    return
            else:
                # case where names[0] contains a possible_affiliation:
                # names[1] is probably someone else
                speaker1 = self.create_speaker_from_name(names[0])
                if speaker1.possible_affiliation:
                    print(f'case: [4] 1st element contains afffiliation, two different speakers "{self.s}"')
                    speaker2 = self.create_speaker_from_name(names[1])
                    self.add_speaker(speaker1)
                    self.add_speaker(speaker2)
                    return
                else:
                    # case names[1] contains an affiliation and names[0] is a single word:
                    # this is probably a single person
                    speaker = self.create_speaker_from_name(names[1])
                    if speaker.possible_affiliation and len(names[0].split()) == 1:
                        print(f'case: [5] 2 elements = single speaker "{self.s}"')
                        speaker = self.create_speaker_from_name(f'{names[1]} {names[0]}')
                        self.add_speaker(speaker)
                        # assuming [lastname, firstname] but this could be wrong?
                        return
                    else:
                        if self.contains_conjunction(names):
                            # case where there are two elements but one contains conjunctions
                            # this means more than 2 speakers so we let the next section handle it
                            print(f'case: [6] 2 elements with conjunctions "{self.s}"')
                        else:
                            # case where there are two elements only
                            print(f'case: [7] 2 elements all other cases "{self.s}"')
                            # we assume [lastname, firstname]
                            speaker = self.create_speaker_from_name(f'{names[1]} {names[0]}')
                            self.add_speaker(speaker)
                            return
                            # possible outstanding cases:
                            # * two speakers no affiliation
                            # * two speakers both with affiliations?
                            # * names[1] contains an affiliation but names[0] has more than one word
                            #   (so same affiliation should apply to both speakers)
        # we reverse the list to apply the final affiliation to each of the preceding speakers
        last_affiliation = None
        if self.contains_conjunction(names):
            names = ','.join(names)
            names = self.replace_conjunctions(names)
            names = self.split_names(names)
        for name in reversed(names):
            print(f'case: [8] more than 2 elements "{self.s}"')
            speaker = self.create_speaker_from_name(name)
            if not speaker.possible_affiliation and last_affiliation:
                speaker.possible_affiliation = last_affiliation
            last_affiliation = speaker.possible_affiliation
            self.add_speaker(speaker)

    def add_speaker(self, speaker):
        print(f'adding speaker: "{speaker}"')
        self.speakers.add(speaker)


    def replace_english_phrases(self):
        phrases = [
            r'\(?Parliament adopted the resolution\)?',
            r'\(?Parliament adopted the Commission proposal\)?',
            r'\(?Parliament adopted the legislative resolution\)?',
            r'\(?Parliament gave its assent\)?',
            r'\(?Parliament rejected the motion for a resolution\)?',
            r'\(?Parliament rejected the[^\)]*\)?',
            r'\((?:The )?Parliament[^\)]*\)',
            r'\(The [Hh]ouse[^\)]*\)',
            r'\(*The Minutes were approved\)*',
            r'\(* *Approval of the [Mm]inutes(?: of the previous sitting[s]?)? *\)*',
            r'\(Explanation[s]? of (?:the )?vote[^\)]*\)',
            r'\(For (?:the )?results [^\)]*\)',
            r'\(For the outcome [^\)]*\)',
            r'\(The explanation[^\)]*\)',
            r'\(The Member[^\)]*\)',
            r'\(Members[^\)]*\)',
            r'\(The meeting was[^\)]*\)',
            r'\(The oral amendment was[^\)]*\)',
            r'\(The order of business[^\)]*\)',
            r'\([Tt]he (?:formal )?sitting [^\)]*\)',
            r'\([Tt]he speaker [^\)]*\)',
            r'\([Tt]he request [^\)]*\)',
            r'\([Tt]he report [^\)]*\)',
            r'\([Tt]he session was [^\)]*\)',
            r'\(The Commissioner [^\)]\)',
            r'\(The President [^\)]\)',
            r'\(The Assembly [^\)]\)',
            r'\(The amendment [^\)]\)',
            r'\(Text [^\)]\)',
            r'\(Abbreviated [^\)]\)',
            r'\(adopted [^\)]\)',
            r'\(During successive [^\)]\)',
            r'\([Tt]he proposal[^)]*\)',
            r'\(The vote [^)]*\)',
            r'\(Intervention cut short pursuant to[^\)]*\)',
            r'\(In successive votes[^)]*\)',
            r'\(Mixed react[^)]*\)',
            r'\(Laughter and applause\)',
            r'\(Laughter\)',
            r'Statement by'
            r'\(*Vigorous applause\)*',
            r'\(*Loud applause\)*',
            r'\([^\)]*[Aa]pplause[^\)]*\)',
            r'\([^\)]*[Ll]aughter[^\)]*\)',
            r'\([^\)]*[Hh]eckling[^\)]*\)',
            r'\(*Murmurs of dissent\)*',
            r'\(Exclamations\)',
            r'\(Muted applause\)',
            r'\(*Adjournment of the session\)*',
            r'Report \([^\)]\/[^\)]*\)',
            r'Draft Amendment No',
        ]
        r = '|'.join(phrases)
        regex = re.compile(f'({r})')
        self.data = regex.sub('', self.data)

    @staticmethod
    def contains_conjunction(s):
        for n in s:
            if ' and ' in n or ' et ' in n or ' & ' in n:
                return True
        return False

    @staticmethod
    def process_affiliation(s):
        a = s
        print(f'invalid before: {a}')
        a = a.replace('(', '')
        a = a.replace(')', '')
        a = a.strip(',.–‘v ')
        a = re.sub(r' *(?:on behalf o[fn] )?(?:for)?(?:the)? ? ?(\S+) ? ?(?:[Gg]roup)?.*', '\g<1>', a)
        print(f'invalid after: {a}')
        a = a.replace('ARE', 'ERA')
        a = a.replace('PPE–DE', 'EPP-ED')
        a = a.replace('PPE-DE', 'EPP-ED')
        a = a.replace('PPE', 'EPP-ED')
        a = a.replace('ALDE-DE', 'ALDE')
        a = a.replace('Verts/ALE', 'G/EFA')
        a = a.replace('PSE', 'PES')
        a = a.replace('PSSE', 'PES')
        a = a.replace('GUE/NGL', 'EUL/NGL')
        a = a.replace('I-EDN', 'I-EN')
        a = a.replace('UPE', 'UFE')
        a = a.replace('TDI', 'TGI')
        a = a.replace('S&amp;D', 'S&D')
        a = a.replace('S-D', 'S&D')
        if a and Intervention.is_valid_affiliation(a):
            return a
        else:
            print(f'invalid affiliation: "{a}"')
            print(f'invalid affiliation string: "{s}"')

    @staticmethod
    def correct_language(s):
        # verified by cross-referencing the other languages
        l = s
        l = l.replace('SI', 'SL')
        l = l.replace('NI', 'FR')
        l = l.replace('GR', 'EL')
        l = l.replace('ER', 'EL')
        l = l.replace('SP', 'ES')
        l = l.replace('NO', 'NL')
        l = l.replace('IN', 'IT')
        l = l.replace('UK', 'EN')
        l = l.replace('UN', 'EN')
        l = l.replace('CZ', 'CS')
        l = l.replace('DK', 'DA')
        l = l.replace('CA', '')
        l = l.replace('EM', '')
        if l != '':
            return l

    @staticmethod
    def split_names(s):
        if not s:
            return ''
        n = s
        # some corrections early here because it affects parsing
        n = n.replace('S&amp;D', 'S&D)')
        n = n.replace('Róża, ', 'Róża ')
        n = n.replace(' )', ')')
        n = n.rstrip(' ,')  # FIXME remove \xa0 here too
        return [p.strip(' –-.?') for p in n.split(',')]

    @staticmethod
    def replace_conjunctions(s):
        n = s
        n = n.replace(' & ', ',')
        n = n.replace(' and ', ',')
        n = n.replace(' et ', ',')
        return n

    @staticmethod
    def remove_non_names(s):
        n = s.strip()
        bad_name_beginnings = ['on ', 'Recommendation', '1', '-', '[', '*', 'Draft', '&', 'European', 'Motion', 'and']
        for b in bad_name_beginnings:
            if n.startswith(b):
                return ''
        bad_name_substrings = ['andlt', 'taken over', 'on behalf of', 'proposal', 'replaced by']
        for b in bad_name_substrings:
            if b in n.lower():
                return ''
        return n

    @staticmethod
    def is_valid_affiliation(s):
        if s in Intervention.valid_affiliations:
            return True
        return False

    @staticmethod
    def create_speaker_from_name(s):
        """ We try to find a possible affiliation in the NAME tag first
            If none exists, we create a speaker
            If it exists, we parse it out and create a speaker from the rest
        """
        match = re.match(r'(.+) +\( *(\S+) *\)\.?\,?', s)
        if not match:
            return Speaker(s)
        name = match.group(1).rstrip()
        print(f'name: {name}')
        possible_affiliation = Intervention.process_affiliation(match.group(2))
        print(f'possible affiliation: {possible_affiliation}')
        return Speaker(name, possible_affiliation=possible_affiliation)

    @staticmethod
    def find_possible_language(s):
        match = re.match(r'\( *([A-Z][A-Z]) *\)', s)
        if match:
            possible_language = match.group(1)
            if Intervention.is_valid_language(possible_language):
                print(f'possible lang: {possible_language}')
                return possible_language

    def parse_affiliation(self):
        match = re.match(r'<.*AFFILIATION="(.*)"/?>', self.s)
        if match:
            m = match.group(1)
            self.possible_language = Intervention.find_possible_language(m)
            affiliation = self.process_affiliation(m)
            if affiliation:
                for speaker in self.speakers:
                    speaker.affiliation = affiliation
                    print(f'affiliation: {speaker.affiliation}')
                    a = speaker.affiliation
                    pa = speaker.possible_affiliation
                    if pa and a != pa:
                        print(f'affiliation mismatch: "{a}" vs "{pa}" -> "{self.s}"')
                return
        for speaker in self.speakers:
            pa = speaker.possible_affiliation
            if pa:
                speaker.affiliation = pa
                print(f'affiliation: {pa}')
            else:
                print(f'invalid affiliation: {pa}')
        else:
            print(f'affiliation not found: {self.s}')

    @staticmethod
    def is_valid_language(l):
        return l in valid_langs

    def parse_language(self):
        match = re.match(r'<.*LANGUAGE="([A-Z][A-Z])".*>', self.s)
        if match:
            language = match.group(1)
            language = self.correct_language(language)
            if self.is_valid_language(language):
                print(f'language: {language}')
                self.language = language
                return
            else:
                print(f'invalid language: {language}')
        if self.possible_language:
            print(f'language: {self.possible_language}')
            self.language = self.possible_language
            return
        print(f'language not found: {self.s}')


def process():
    corpus_lang = args.language.lower()
    input_path = f'./txt/{corpus_lang}'
    output_path = f'./xml/{corpus_lang}'
    Path(output_path).mkdir(parents=True, exist_ok=True)

    if args.file:
        file_dir = '/'.join(args.file.split('/')[:-1])
        files = [os.fsencode(args.file.split('/')[-1:][0])]
    else:
        files = os.listdir(os.fsencode(input_path))

    for f in files:
        if len(f) != 15:
            print(f'{f} not correct length: {len(f)}')
            continue
        filename = os.fsdecode(f)
        input_filename = os.path.join(input_path, filename)
        interventions = []
        with open(input_filename) as ifile:
            print(f'Processing {input_filename}')
            speaker_section = False
            for line in ifile:
                if line.startswith('<CHAPTER') or line.startswith('VOTE') or \
                   line.startswith('The sitting was ') or line.startswith('Votes') or \
                   line.startswith('Statement by '):
                    speaker_section = False
                    continue
                if line.startswith('Applause') or line.startswith('Loud applause') or \
                   line.startswith('Loud and sustained applause') or line.startswith('Loud Applause') or \
                   line.startswith('Sustained applause'):
                    continue
                if 'SPEAKER' in line:
                    speaker_section = True
                    i = Intervention(line)
                    interventions.append(i)
                else:
                    if speaker_section:
                        i.add_data(line)
        for i in interventions:
            i.finalize()
            if i.language == 'UNKNOWN':
                for lang in valid_langs:
                    if i.language != 'UNKNOWN':
                        break
                    la = lang.lower()
                    if corpus_lang == la:
                        continue
                    base_path = input_path.replace(f'{corpus_lang}', la)
                    input_filename = os.path.join(base_path, filename)
                    try:
                        with open(input_filename) as ifile:
                            print(f'Opening {input_filename} for unknown lang for SPEAKER ID={i.speech_id}')
                            for line in ifile:
                                regex = f'SPEAKER ID="?{i.speech_id}"? .*LANGUAGE="([A-Z][A-Z])"'
                                match = re.search(regex, line)
                                if match:
                                    new_lang = match.group(1)
                                    if new_lang in valid_langs:
                                        print(f'Setting language to {new_lang}')
                                        i.language = new_lang
                                        break
                                    else:
                                        print(f'bad new_lang: {new_lang}')
                    except FileNotFoundError:
                        print(f'{input_filename} does not exist')

        output_parts = filename.replace('.txt', '.xml').replace('ep-', '').split('-')
        if int(output_parts[0]) < 50:
            century = '20'
        else:
            century = '19'
        o = corpus_lang.upper() + century + ''.join(output_parts)
        output_filename = os.fsdecode(os.path.join(output_path, o))
        with open(output_filename, 'w') as ofile:
            print(f'Writing {output_filename}')
            ofile.write(f' <?xml version="1.0" encoding="UTF-8"?>\n')
            ofile.write(f'<ecpc_EP>\n')
            ofile.write(f'  <header filename="{o.replace(".xml", ".xml")}" language="{corpus_lang.upper()}"/>\n')
            ofile.write(f'  <body>\n')
            for i in interventions:
                ofile.write(f'    <intervention>\n')
                for speaker in i.speakers:
                    ofile.write(f'      <speaker>\n')
                    ofile.write(f'        <name>{speaker.name}</name>\n')
                    ofile.write(f'        <affiliation EPparty="{speaker.affiliation}"/>\n')
                    ofile.write(f'        <post/>\n')
                    ofile.write(f'      </speaker>\n')
                ofile.write(f'      <speech ref="s{i.speech_id}" language="{i.language}">{i.data.strip()}</speech>\n')
                ofile.write(f'    </intervention>\n')
            ofile.write('  </body>\n')
            ofile.write('<back/>\n')
            ofile.write('</ecpc_EP>\n')
#    for speaker in all_speakers:
#        print(f'all_speakers:{speaker}')


def main():
    process()


parser = argparse.ArgumentParser()
parser.add_argument('--file', help='File to operate on')
parser.add_argument('--language', choices=valid_langs, default='EN', help='Source language')
args = parser.parse_args()

if __name__ == '__main__':
    main()
