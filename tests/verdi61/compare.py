"""Compare reviewed public waveforms by exact values and physical timestamps."""
import re
import math
import csv
import io


UNITS={'fs':1,'ps':1000,'ns':10**6,'us':10**9,'ms':10**12,'s':10**15}


def reviewed_interval(records, ticks, begin_fs, end_fs):
    if any(not record['values'] for record in records.values()):
        raise ValueError('missing reviewed signal values')
    if begin_fs is not None or end_fs is not None:
        if begin_fs is None or end_fs is None or not 0<=begin_fs<end_fs or ticks<end_fs:
            raise ValueError('incomplete reviewed interval coverage')
        for path,record in records.items():
            initial=[row for row in record['values'] if row[0]<=begin_fs]
            if not initial:raise ValueError('missing initial reviewed value: '+path)
            record['values']=[[begin_fs,initial[-1][1]]]+[
                row for row in record['values'] if begin_fs<row[0]<=end_fs]
    return records


def canonical_string_trace(text, paths, begin_fs, end_fs):
    """Read full-file native fsdbreport CSV for strings omitted by VCD."""
    rows=csv.reader(io.StringIO(text));header=next(rows,[])
    scale=re.fullmatch(r'Time\((\d+)(fs|ps|ns|us|ms|s)\)',header[0] if header else '')
    if not scale:raise ValueError('missing native string-report timescale')
    multiplier=int(scale[1])*UNITS[scale[2]]
    if len(header)!=len(set(header)):raise ValueError('duplicate string-report columns')
    selected=set(paths)
    missing=selected-set(header[1:])
    if missing:raise ValueError('missing reviewed strings: '+', '.join(sorted(missing)))
    records={path:dict(kind='string',width=0,values=[]) for path in paths}
    columns={path:header.index(path) for path in paths};ticks=0
    for row in rows:
        if len(row)!=len(header):raise ValueError('incomplete string-report row')
        new_ticks=int(row[0])*multiplier
        if new_ticks<ticks:raise ValueError('string-report times are not monotonic')
        ticks=new_ticks
        for path,column in columns.items():
            values=records[path]['values'];value=row[column]
            if not values or values[-1][1]!=value:values.append([ticks,value])
    return reviewed_interval(records,ticks,begin_fs,end_fs)


def canonical_trace(text, paths, begin_fs=None, end_fs=None):
    scale=re.search(r'\$timescale\s+(\d+)\s*(fs|ps|ns|us|ms|s)\s+\$end',text)
    if not scale:
        raise ValueError('missing VCD timescale')
    multiplier=int(scale[1])*UNITS[scale[2]]
    scopes=[];selected=set(paths);codes={};records={};body=False;ticks=0
    for line in text.splitlines():
        line=line.strip()
        if not body:
            fields=line.split()
            if line.startswith('$scope '):scopes.append(fields[2].lstrip('\\'))
            elif line.startswith('$upscope'):scopes.pop()
            elif line.startswith('$var '):
                path='/'+'/'.join(scopes+[fields[4].lstrip('\\')])
                if path in selected:
                    records[path]=dict(kind=fields[1],width=int(fields[2]),values=[])
                    codes.setdefault(fields[3],[]).append(path)
            elif line.startswith('$enddefinitions'):body=True
            continue
        if not line or line.startswith('$'):continue
        if line.startswith('#'):
            new_ticks=int(line[1:])*multiplier
            if new_ticks<ticks:raise ValueError('VCD times are not monotonic')
            ticks=new_ticks;continue
        prefix=line[0].lower()
        if prefix in ('b','r','s'):
            value,code=line[1:].split(None,1)
        elif prefix in ('0','1','x','z'):
            value,code=prefix,line[1:]
        else:
            raise ValueError('unsupported VCD value: '+line)
        for path in codes.get(code,[]):
            record=records[path]
            if prefix=='r':
                real=float(value)
                if not math.isfinite(real):raise ValueError('nonfinite reviewed real: '+path)
                normalized=real.hex()
            elif prefix=='s':normalized=value
            elif set(value.lower())<={'0','1'}:normalized=str(int(value,2))
            else:
                bits=value.lower();normalized=bits.rjust(record['width'],bits[0] if bits[0] in 'xz' else '0')
            values=record['values']
            if not values or values[-1][1]!=normalized:values.append([ticks,normalized])
    missing=selected-set(records)
    if missing:raise ValueError('missing reviewed signals: '+', '.join(sorted(missing)))
    return reviewed_interval(records,ticks,begin_fs,end_fs)
