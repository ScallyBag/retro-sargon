/*

  A program to convert Z80 assembly language to X86
  
  */

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <deque>
#include <map>
#include <set>
#include <algorithm>
#include "util.h"

void translate_init();
void translate_init_slim_down();

// Return true if translated    
bool translate_x86( const std::string &line, const std::string &instruction, const std::vector<std::string> &parameters, std::set<std::string> &labels, std::string &out );

void convert( std::string fin, std::string asm_fout,  std::string report_fout, std::string asm_interface_fout );
std::string detabify( const std::string &s, bool push_comment_to_right=false );

// After optional transformation, the original line can be kept, discarded or commented out
enum original_t { original_keep, original_comment_out, original_discard };
original_t original_switch = original_discard;

int main( int argc, const char *argv[] )
{
#if 1
    const char *test_args[] =
    {
        "Release/z80-to-x86.exe",
        "../stages/sargon-z80-and-x86.asm",
        "../stages/sargon-x86-COMPARE.asm"
    };
    argc = sizeof(test_args) / sizeof(test_args[0]);
    argv = test_args;
#endif
    const char *usage=
    "Read, understand, convert sargon source code\n"
    "Usage:\n"
    " z80-to-x86 [switches] z80-code-in.asm x86-code-out.asm [report.txt] [asm-interface.h]\n"
    "Switches:\n"
    " -relax Relax strict Z80->X86 flag compatibility. Applying this flag eliminates LAHF/SAHF pairs around\n"
    "        some X86 instructions. Reduces compatibility (burden of proof passes to programmer) but improves\n"
    "        performance. For Sargon, manual checking suggests it's okay to use this flag.\n"
    "The original line can be kept, discarded or commented out\n"
    " so -original_keep or -original_comment_out or -original_discard, default is -original_discard\n"
    "Note that all three output files will be generated, if the optional output filenames aren't\n"
    "provided, names will be auto generated from the main output filename";
    int argi = 1;
    while( argc >= 2)
    {
        std::string arg( argv[argi] );
        if( arg[0] != '-' )
            break;
        else
        {
            if( arg == "-original_keep" )
                original_switch = original_keep;
            else if( arg == "-original_discard" )
                original_switch =original_discard;
            else if( arg == "-original_comment_out" )
                original_switch = original_comment_out;
            else
            {
                printf( "Unknown switch %s\n", arg.c_str() );
                printf( "%s\n", usage );
                return -1;
            }
        }
        argc--;
        argi++;
    }
    bool ok = (argc==3 || argc==4 || argc==5);
    if( !ok )
    {
        printf( "%s\n", usage );
        return -1;
    }
    std::string fin ( argv[argi] );
    std::string fout( argv[argi+1] );
    std::string report_fout = argc>=4 ? argv[argi+2] : fout + "-report.txt";
    std::string asm_interface_fout = argc>=5 ? argv[argi+3] : fout + "-asm-interface.h";
    printf( "convert(%s,%s,%s,%s)\n", fin.c_str(), fout.c_str(), report_fout.c_str(), asm_interface_fout.c_str() );
    convert(fin,fout,report_fout,asm_interface_fout);
    return 0;
}

enum statement_typ {empty, discard, illegal, comment_only, comment_only_indented, equate, normal};

struct statement
{
    statement_typ typ;
    std::string label;
    bool label_has_colon_terminator;
    std::string equate;
    std::string instruction;
    std::vector<std::string> parameters;
    std::string comment;
};

struct name_plus_parameters
{
    //name_plus_parameters( std::set<std::vector<std::string>> &p ) : name(n), parameters(p) {}
    std::string name;
    std::set<std::vector<std::string>> parameters;
};

// Check ASM line syntax - it's not an industrial strength ASM parser, but it's more than
//  sufficient in most cases and will highlight cases where a little manual editing/conversion
//  might be required
// Supported syntax:
//  [label[:]] instruction [parameters,..]
// label and instruction must be alphanum + '_' + '.'
// parameters are less strict, basically anything between commas
// semicolon anywhere initiates comment, so ;rest of line is comment
// complete parameters can be singly ' or " quoted. Commas and semicolons lose their magic in quotes
//
static void parse( const std::string &line, statement &stmt )
{
    enum { init, in_comment, in_label, before_instruction, in_instruction, after_instruction,
           in_parm, in_quoted_parm, in_double_quoted_parm,
           between_parms_before_comma, between_parms_after_comma, err } state;
    state = init;
    std::string parm;
    stmt.typ = normal;
    stmt.label_has_colon_terminator = false;
    for( unsigned int i=0; state!=err && i<line.length(); i++ )
    {
        char c = line[i];
        char next = '\0';
        if( i+1 < line.length() )
            next = line[i+1];
        switch( state )
        {
            case init:
            {
                if( c == ';' )
                {
                    state = in_comment;
                    stmt.typ = comment_only;
                }
                else if( c == ' ' )
                {
                    state = before_instruction;
                }
                else if( c == ':' )
                {
                    state = err;
                }
                else
                {
                    state = in_label;
                    stmt.label = c;
                }
                break;
            }
            case in_comment:
            {
                stmt.comment += c;
                break;
            }
            case in_label:
            {
                if( c == ';' )
                {
                    state = in_comment;
                }
                else if( c == ' ' )
                    state = before_instruction;
                else if( c == ':' )
                {
                    if( next==' ' || next=='\0' )
                    {
                        stmt.label_has_colon_terminator = true;
                        state = before_instruction;
                    }
                    else
                        state = err;
                }
                else
                {
                    stmt.label += c;
                }
                break;
            }
            case before_instruction:
            {
                if( c == ';' )
                {
                    state = in_comment;
                    if( stmt.label == "" )
                        stmt.typ = comment_only_indented;
                }
                else if( c != ' ' )
                {
                    state = in_instruction;
                    stmt.instruction += c;
                }
                break;
            }
            case in_instruction:
            {
                if( c == ';' )
                {
                    state = in_comment;
                }
                else if( c == ' ' )
                {
                    state = after_instruction;
                }
                else
                {
                    stmt.instruction += c;
                }
                break;
            }
            case after_instruction:
            {
                if( c == ';' )
                {
                    state = in_comment;
                }
                else if( c != ' ' )
                {
                    parm = c;
                    if( c == '\'' )
                        state = in_quoted_parm;
                    else if( c == '\"' )
                        state = in_double_quoted_parm;
                    else
                        state = in_parm;
                }
                break;
            }
            case in_parm:
            {
                if( c == ';' )
                {
                    util::rtrim(parm);
                    stmt.parameters.push_back(parm);
                    state = in_comment;
                }
                else if( c == ',' )
                {
                    util::rtrim(parm);
                    stmt.parameters.push_back(parm);
                    state = between_parms_after_comma;
                }
                else
                {
                    parm += c;
                }
                break;
            }
            case in_quoted_parm:
            {
                if( c == '\'' )
                {
                    parm += c;
                    stmt.parameters.push_back(parm);
                    state = between_parms_before_comma;
                }
                else
                {
                    parm += c;
                }
                break;
            }
            case in_double_quoted_parm:
            {
                if( c == '\"' )
                {
                    parm += c;
                    stmt.parameters.push_back(parm);
                    state = between_parms_before_comma;
                }
                else
                {
                    parm += c;
                }
                break;
            }
            case between_parms_before_comma:
            {
                if( c == ';' )
                {
                    state = in_comment;
                }
                else if( c == ',' )
                {
                    state = between_parms_after_comma;
                }
                break;
            }
            case between_parms_after_comma:
            {
                if( c == ',' )
                    state = err;
                else if( c != ' ' )
                {
                    parm = c;
                    if( c == '\'' )
                        state = in_quoted_parm;
                    else if( c == '\"' )
                        state = in_double_quoted_parm;
                    else
                        state = in_parm;
                }
                break;
            }
        }
    }
    const char *identifier_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._";
    if( util::toupper(stmt.label).find_first_not_of(identifier_chars) != std::string::npos )
        stmt.typ = illegal;
    if( util::toupper(stmt.instruction).find_first_not_of(identifier_chars) != std::string::npos )
        stmt.typ = illegal;
    if( state == init )
        stmt.typ = empty;
    else if( state==before_instruction && stmt.label=="" )
        stmt.typ = empty;
    else if( state == err || state==between_parms_after_comma || state==in_quoted_parm || state==in_double_quoted_parm )
        stmt.typ = illegal;
    else if( state == in_parm )
    {
        util::rtrim(parm);
        stmt.parameters.push_back(parm);
    }
    stmt.instruction = util::toupper(stmt.instruction);
    if( stmt.instruction == "EQU" )
    {
        if( stmt.label == "" || stmt.label_has_colon_terminator || stmt.parameters.size()!=1 )
            stmt.typ = illegal;
        else
        {
            stmt.typ = equate;
            stmt.equate = stmt.label;
            stmt.label = "";
        }
    }
}

void convert( std::string fin, std::string fout, std::string report_fout, std::string asm_interface_fout )
{
    std::ifstream in(fin);
    if( !in )
    {
        printf( "Error; Cannot open file %s for reading\n", fin.c_str() );
        return;
    }
    std::ofstream asm_out(fout);
    if( !asm_out )
    {
        printf( "Error; Cannot open file %s for writing\n", fout.c_str() );
        return;
    }
    std::ofstream report_out(report_fout);
    if( !report_out )
    {
        printf( "Error; Cannot open file %s for writing\n", report_fout.c_str() );
        return;
    }
    std::ofstream h_out(asm_interface_fout);
    if( !h_out )
    {
        printf( "Error; Cannot open file %s for writing\n", asm_interface_fout.c_str() );
        return;
    }
    std::set<std::string> labels;
    std::map< std::string, std::vector<std::string> > equates;
    std::map< std::string, std::set<std::vector<std::string>> > instructions;
    bool data_mode = true;
    translate_init();
    translate_init_slim_down();

    // .IF controls let us switch between three modes (currently)
    enum { mode_normal, mode_pass_thru, mode_suspended } mode = mode_normal;

    unsigned int track_location = 0;
    for(;;)
    {
        std::string line;
        if( !std::getline(in,line) )
            break;
        util::rtrim(line);
        std::string line_original = line;
        util::replace_all(line,"\t"," ");
        statement stmt;
        parse( line, stmt );
        bool done = false;

        // Reduce to a few simple types of line
        std::string line_out="";
        done = false;
        switch(stmt.typ)
        {
            case empty:
                line_out = "EMPTY"; done=true;
                break;
            case discard:
                line_out = "DISCARD"; done=true; break;
            case illegal:
                line_out = "ILLEGAL> ";
                line_out += line_original;
                done = true;
                break;
            case comment_only:
            case comment_only_indented:
                line_out = stmt.typ==comment_only_indented ? "COMMENT_ONLY> " : "COMMENT_ONLY_INDENTED> ";
                line_out += stmt.comment;
                done = true;
                break;
            case normal:
                line_out = "NORMAL";
                break;
            case equate:
                line_out = "EQUATE"; break;
        }

        // Line by line reporting
        if( !done && mode==mode_normal )
        {
            if( stmt.label != "" )
            {
                labels.insert(stmt.label);
                line_out += " label: ";
                line_out += "\"";
                line_out += stmt.label;
                line_out += "\"";
            }
            if( stmt.equate != "" )
            {
                line_out += " equate: ";
                line_out += "\"";
                line_out += stmt.equate;
                line_out += "\"";
                auto it = equates.find(stmt.equate);
                if( it != equates.end() )
                    line_out += " Error: dup equate";
                else
                    equates.insert( std::pair<std::string,std::vector<std::string>> (stmt.equate, stmt.parameters) );
            }
            if( stmt.instruction != "" )
            {
                line_out += " instruction: ";
                line_out += "\"";
                line_out += stmt.instruction;
                line_out += "\"";
                instructions[stmt.instruction].insert(stmt.parameters);
            }
            bool first=true;
            for( std::string parm: stmt.parameters )
            {
                line_out += first ? " parameters: " : ",";
                line_out += parm;
                first = false;
            }
        }
        if( !done && mode==mode_normal )
            util::putline(report_out,line_out);

        // My invented directives
        bool handled=false;
        if( stmt.label=="" )
        {
            if( stmt.instruction == ".DATA" )
            {
                data_mode = true;
                handled = true;         
            }
            else if( stmt.instruction == ".CODE" )
            {
                data_mode = false;
                handled = true;         
            }
            else if( stmt.instruction == ".IF_Z80" )
            {
                mode = mode_suspended;
                handled = true;         
            }
            else if( stmt.instruction == ".IF_X86" )
            {
                mode = mode_pass_thru;
                handled = true;         
            }
            else if( stmt.instruction == ".ELSE" )
            {
                if( mode == mode_suspended )
                    mode = mode_normal;
                else
                    printf( "Error, unexpected .ELSE\n" );
                handled = true;         
            }
            else if( stmt.instruction == ".ENDIF" )
            {
                mode = mode_normal;
                handled = true;         
            }
        }

        // Pass through new X86 code
        if( mode==mode_pass_thru && !handled )
        {
            util::putline( asm_out, line_original );
            continue;
        }

        if( mode == mode_suspended  )
            continue;

        // Generate assembly language output
        switch( stmt.typ )
        {
            case empty:
                line_original = "";
                line_original = detabify(line_original);
                util::putline( asm_out, line_original );
                break;
            case comment_only:
                line_original = ";" + stmt.comment;
                line_original = detabify(line_original);
                util::putline( asm_out, line_original );
                break;
            case comment_only_indented:
                line_original = "\t;" + stmt.comment;
                line_original = detabify(line_original, true );
                util::putline( asm_out, line_original );
                break;
        }
        if( stmt.typ!=normal && stmt.typ!=equate )
            continue;

        if( handled || mode == mode_pass_thru )
            continue;

        switch( original_switch )
        {
            case original_comment_out:
            {
                util::putline( asm_out, detabify( ";" + line_original) );
                break;
            }
            case original_keep:
            {
                util::putline( asm_out, detabify(line_original) );
                break;
            }
            default:
            case original_discard:
                break;
        }

        // Generate code
        {
            std::string str_location = util::sprintf( "0%xh", track_location );
            std::string asm_line_out;
            if( stmt.equate != "" )
            {
                asm_line_out = stmt.equate;
                asm_line_out += "\tEQU";
                bool first = true;
                for( std::string s: stmt.parameters )
                {
                    if( first && s[0]=='$' )
                        s = str_location + s.substr(1);
                    asm_line_out += first ? "\t" : ",";
                    first = false;
                    asm_line_out += s;
                }
                if( first )
                {
                    printf( "Error: No EQU parameters, line=[%s]\n", line.c_str() );
                }
            }
            else if( stmt.label != "" && stmt.instruction=="" )
            {
                if( data_mode )
                {
                    asm_line_out = util::sprintf( "%s\tEQU\t%s", stmt.label.c_str(), str_location.c_str() );
                    std::string c_include_line_out = util::sprintf( "    const int %s = 0x%04x;", stmt.label.c_str(), track_location  );
                    util::putline( h_out, c_include_line_out );
                }
                else
                    asm_line_out = stmt.label + ":";
                if( stmt.comment != "" )
                {
                    asm_line_out += "\t;";
                    asm_line_out += stmt.comment;
                }
            }
            else if( stmt.instruction!="" )
            {
                std::string out;
                bool generated = false;
                bool show_original = false;
                if( data_mode && (stmt.instruction == "ORG" || stmt.instruction == "DS"  ||
                                    stmt.instruction == "DB" || stmt.instruction == "DW")
                    )
                {
                    if( stmt.parameters.size() == 0 )
                    {
                        printf( "Error, at least one parameter required. Line: [%s]\n", line_original.c_str() );
                        show_original = true;
                    }
                    else
                    {
                        bool first = true;
                        bool commented = false;
                        std::string parameter_list;
                        for( std::string s: stmt.parameters )
                        {
                            parameter_list += first ? "" : ",";
                            first = false;
                            parameter_list += s;
                        }
                        if( stmt.instruction == "ORG" )
                        {
                            asm_line_out += util::sprintf( ";\tORG\t%s", parameter_list.c_str() );
                            std::string s=stmt.parameters[0];
                            unsigned int len = s.length();
                            unsigned int base = 10;
                            if( len>0 && (s[len-1]=='H' || s[len-1]=='h') )
                            {
                                len--;
                                s = s.substr(0,len);
                                base = 16;
                            }
                            unsigned int accum=0;
                            bool err = (len<1);
                            for( char c: s )
                            {
                                accum *= base;
                                if( '0'<=c && c<='9' )
                                    accum += (c-'0');
                                else if( base==16 && 'a'<=c && c<='f' )
                                    accum += (10+c-'a');
                                else if( base==16 && 'A'<=c && c<='F' )
                                    accum += (10+c-'A');
                                else
                                {
                                    err = true;
                                    break;
                                }
                            }
                            if( err )
                            {
                                printf( "Error, ORG parameter is unparseable. Line: [%s]\n", line_original.c_str() );
                                show_original = true;
                            }
                            else if( accum < track_location )
                            {
                                printf( "Error, ORG parameter attempts unsupported reposition earlier in memory. Line: [%s]\n", line_original.c_str() );
                                show_original = true;
                            }
                            else if( accum > track_location )
                            {
                                asm_line_out += util::sprintf( "\n\tDB\t%d\tDUP (?)\t;Padding bytes to ORG location", accum - track_location );
                            }
                            track_location = accum;
                        }
                        if( stmt.label != "" )
                        {
                            std::string c_include_line_out = util::sprintf( "    const int %s = 0x%04x;", stmt.label.c_str(), track_location  );
                            util::putline( h_out, c_include_line_out );
                            asm_line_out = util::sprintf( "%s\tEQU\t%s", stmt.label.c_str(), str_location.c_str() );
                            if( stmt.comment != "" )
                            {
                                asm_line_out += "\t;";
                                asm_line_out += stmt.comment;
                                commented = true;
                            }
                            asm_line_out += "\n";
                        }
                        if( stmt.instruction == "DS" )
                        {
                            asm_line_out += util::sprintf( "\tDB\t%s\tDUP (?)", parameter_list.c_str() );
                            unsigned int nbr = atoi( stmt.parameters[0].c_str() );
                            if( nbr == 0 )
                            {
                                printf( "Error, .BLKB parameter is zero or unparseable. Line: [%s]\n", line_original.c_str() );
                                show_original = true;
                            }
                            track_location += nbr;
                        }
                        else if( stmt.instruction == "DB" )
                        {
                            asm_line_out += util::sprintf( "\tDB\t%s", parameter_list.c_str() );
                            track_location += stmt.parameters.size();
                        }
                        else if( stmt.instruction == "DW" )
                        {
                            asm_line_out += util::sprintf( "\tDW\t%s", parameter_list.c_str() );
                            track_location += (2 * stmt.parameters.size());
                        }
                        if( !commented && stmt.comment != "" )
                        {
                            asm_line_out += "\t;";
                            asm_line_out += stmt.comment;
                        }
                    }
                }
                else
                {
                    generated = translate_x86( line_original, stmt.instruction, stmt.parameters, labels, out );
                    show_original = !generated;
                }
                if( show_original )
                {
                    asm_line_out = line_original;
                }
                if( generated )
                {
                    asm_line_out = stmt.label;
                    if( stmt.label == "" )
                        asm_line_out = "\t";
                    else
                        asm_line_out += (data_mode?"\t":":\t");
                    if( original_switch == original_comment_out )
                        asm_line_out += out;    // don't worry about comment
                    else
                    {
                        size_t offset = out.find('\n');
                        if( offset == std::string::npos )
                        {
                            asm_line_out += out;
                            if( stmt.comment != "" )
                            {
                                asm_line_out += "\t;";
                                asm_line_out += stmt.comment;
                            }
                        }
                        else
                        {
                            asm_line_out += out.substr(0,offset);
                            if( stmt.comment != "" )
                            {
                                asm_line_out += "\t;";
                                asm_line_out += stmt.comment;
                            }
                            asm_line_out += out.substr(offset);
                        }
                    }
                }
            }
            asm_line_out = detabify(asm_line_out, true );
            util::putline( asm_out, asm_line_out );
        }
    }

    // Summary report
    util::putline(report_out,"\nLABELS\n");
    for( const std::string &s: labels )
    {
        util::putline(report_out,s);
    }
    util::putline(report_out,"\nEQUATES\n");
    for( const std::pair<std::string,std::vector<std::string>> &p: equates )
    {
        std::string s;
        s += p.first;
        s += ": ";
        bool init = true;
        for( const std::string &t: p.second )
        {
            s += init?" ":", ";
            init = false;
            s += t;
        }
        util::putline(report_out,s);
    }
    util::putline(report_out,"\nINSTRUCTIONS\n");
    for( const std::pair<std::string,std::set<std::vector<std::string>> > &p: instructions )
    {
        std::string s;
        s += p.first;
        util::putline(report_out,s);
        for( const std::vector<std::string> &v: p.second )
        {
            s = " >";
            bool init = true;
            for( const std::string &t: v )
            {
                s += init?" ":", ";
                init = false;
                s += t;
            }
            util::putline(report_out,s);
        }
    }
}

std::string detabify( const std::string &s, bool push_comment_to_right )
{
    std::string ret;
    int idx=0;
    int len = s.length();
    for( int i=0; i<len; i++ )
    {
        char c = s[i];
        if( c == '\n' )
        {
            ret += c;
            idx = 0;
        }
        else if( c == '\t' )
        {
            int comment_column   = ( i+1<len && s[i+1]==';' ) ? (push_comment_to_right?48:32) : 0;
            int tab_stops[]      = {8,16,24,32,40,48,100};
            int tab_stops_wide[] = {9,17,25,33,41,49,100};
            bool wide = (original_switch == original_comment_out);
            int *stops = wide ? tab_stops_wide : tab_stops;
            for( int j=0; j<sizeof(tab_stops)/sizeof(tab_stops[0]); j++ )
            {
                if( comment_column>0 || idx<stops[j] )
                {
                    int col = comment_column>0 ? comment_column : stops[j];
                    if( idx >= col )
                        col = idx+1;
                    while( idx < col )
                    {
                        ret += ' ';
                        idx++;
                    }
                    break;
                }
            }
        }
        else
        {
            ret += c;
            idx++;
        }
    }
    return ret;
}


enum ParameterPattern
{
    echo,
    push_parameter,
    pop_parameter,
    reg8,
    set_n_parm,
    clr_n_parm,
    dst_src,
    dst_src_8_more,
    dst_src_16,
    parm_8_more,
    parm_16,
    jnx_around_addr,
    jnx_around,
    jx_addr,
    af_af_dash_more,
    none
};

static int skip_counter=1;

struct MnemonicConversion
{
    const char *x86;
    int nbr_parameters;
    ParameterPattern pp;
};

static std::multimap<std::string,MnemonicConversion> xlat;

enum AddressMode
{
    am_mem,
    am_imm,
    am_reg8,
    am_reg16,
};

bool is_generic( const std::string &parm, std::string &out, AddressMode &gt )
{
    gt = am_imm;
    out = parm;
    bool done = false;
    int len = parm.length();
    if( parm[0] == '(' && len>1 && parm[len-1] == ')' )
    {
        gt = am_mem;
        std::string inner = parm.substr(1,len-2);
        util::ltrim(inner);
        util::rtrim(inner);
        len = inner.length();
        if( len >= 2 )
        {
            std::string possible_reg_idx = inner.substr(0,2);
            std::string upper_possible_reg_idx = util::toupper(possible_reg_idx);
            std::string replacement;
            bool terminated = !isalnum( len>2 ? inner[2] : '\0' );
            if( terminated )
            {
                if( upper_possible_reg_idx=="IX" )
                    util::replace_once( inner, possible_reg_idx, "esi" );
                else if( upper_possible_reg_idx=="IY" )
                    util::replace_once( inner, possible_reg_idx, "edi" );
                else if( upper_possible_reg_idx=="BC" )
                    util::replace_once( inner, possible_reg_idx, "ecx" );
                else if( upper_possible_reg_idx=="DE" )
                    util::replace_once( inner, possible_reg_idx, "edx" );
                else if( upper_possible_reg_idx=="HL" )
                    util::replace_once( inner, possible_reg_idx, "ebx" );
            }
        }
        out = "ptr [ebp+" + inner + "]";
        done = true;
    }
    if( !done )
    {
        std::string s = util::toupper(parm);
        if( s=="A" || s=="B" || s=="C" || s=="D" || s=="E" || s=="H" || s=="L" )
        {
            gt = am_reg8;
            if( s=="A" )
                out = "al";
            else if( s=="B" )
                out = "ch";
            else if( s=="C" )
                out = "cl";
            else if( s=="D" )
                out = "dh";
            else if( s=="E" )
                out = "dl";
            else if( s=="H" )
                out = "bh";
            else if( s=="L" )
                out = "bl";
        }
        else if( s=="BC" || s=="DE" || s=="HL" || s=="IX" || s=="IY" )
        {
            gt = am_reg16;
            if( s=="BC" )
                out = "cx";
            else if( s=="DE" )
                out = "dx";
            else if( s=="HL" )
                out = "bx";
            else if( s=="IX" )
                out = "si";
            else if( s=="IY" )
                out = "di";
        }
    }
    return true;
}

bool is_reg8( const std::string &parm, std::string &out )
{
    std::string s = util::toupper(parm);
    bool ret = true;
    if( s == "A" )
        out = "al";
    else if( s == "B" )
        out = "ch";
    else if( s == "C" )
        out = "cl";
    else if( s == "D" )
        out = "dh";
    else if( s == "E" )
        out = "dl";
    else if( s == "H" )
        out = "bh";
    else if( s == "L" )
        out = "bl";
    else if( s == "(HL)" )
        out = "byte ptr [ebp+ebx]";
    else
        ret = false;
    return ret;
}

bool is_reg16( const std::string &parm, std::string &out )
{
    std::string s = util::toupper(parm);
    bool ret = true;
    if( s == "HL" )
        out = "bx";
    else if( s == "BC" )
        out = "cx";
    else if( s == "DE" )
        out = "dx";
    else if( s == "IX" )
        out = "si";
    else if( s == "IY" )
        out = "di";
    else
        ret = false;
    return ret;
}

bool is_reg8_mem8( const std::string &parm, std::string &out )
{
    bool ret = true;
    AddressMode am;
    ret = is_generic(parm,out,am);
    if( ret )
    {
        ret = (am==am_reg8 || am==am_mem);
        if( am == am_mem )
            out = "byte " + out;
    }
    return ret;
}

bool is_reg16_mem16( const std::string &parm, std::string &out )
{
    bool ret = true;
    AddressMode am;
    ret = is_generic(parm,out,am);
    if( ret )
    {
        ret = (am==am_reg16 || am==am_mem);
        if( am == am_mem )
            out = "word " + out;
    }
    return ret;
}

bool is_conditional( const std::string &parm, std::string &out, std::string &reverse_out )
{

/*            8080                     Z80                        X86
              ----                     ---                        ---
     C=1      C  (JC, RC, CC)          C  (JP C, RET C, CALL C)   C  (JC)
     C=0      NC                       NC                         NC
     Z=1      Z                        Z                          Z
     Z=0      NZ                       NZ                         NZ
     S=1      M                        M                          S
     S=0      P                        P                          NS
     P=1      PE                       PE                         PE
     P=0      PO                       PO                         PO
*/

    bool ret = true;
    std::string s = util::toupper(parm);
    if( s == "C" || s == "Z" )
    {
        out = s;
        reverse_out = "N" + parm;
    }
    else if( s == "NC" || s == "NZ" )
    {
        out = s;
        reverse_out = s.substr(1);
    }
    else if( s == "M" )
    {
        out = "S";
        reverse_out = "NS";
    }
    else if( parm == "P" )
    {
        out = "NS";
        reverse_out = "S";
    }
    else if( s == "PE" )
    {
        out = parm;
        reverse_out = "PO";
    }
    else if( s == "PO" )
    {
        out = "PO";
        reverse_out = "PE";
    }
    else
        ret = false;
    return ret;
}

bool is_n_set( const std::string &parm, std::string &out )
{
    bool ret = true;
    if( parm=="0" )
        out = "1";
    else if( parm=="1" )
        out = "2";
    else if( parm=="2" )
        out = "4";
    else if( parm=="3" )
        out = "8";
    else if( parm=="4" )
        out = "10h";
    else if( parm=="5" )
        out = "20h";
    else if( parm=="6" )
        out = "40h";
    else if( parm=="7" )
        out = "80h";
    else
        ret = false;
    return ret;
}

bool is_n_clr( const std::string &parm, std::string &out )
{
    bool ret = true;
    if( parm=="0" )
        out = "0feh";
    else if( parm=="1" )
        out = "0fdh";
    else if( parm=="2" )
        out = "0fbh";
    else if( parm=="3" )
        out = "0f7h";
    else if( parm=="4" )
        out = "0efh";
    else if( parm=="5" )
        out = "0dfh";
    else if( parm=="6" )
        out = "0bfh";
    else if( parm=="7" )
        out = "07fh";
    else
        ret = false;
    return ret;
}

// Return true if translated    
bool translate_x86( const std::string &line, const std::string &instruction, const std::vector<std::string> &parameters, std::set<std::string> &labels, std::string &x86_out )
{
    x86_out = "";
    auto it1 = xlat.find(instruction.c_str());
    if( it1 == xlat.end() )
    {
        printf( "Error: Unknown instruction %s, line=[%s]\n", instruction.c_str(), line.c_str() );
        return false;
    }
    int count = xlat.count(instruction.c_str());
    auto range = xlat.equal_range(instruction.c_str());
    bool handled = false;
    for( it1 = range.first; !handled && it1 != range.second; ++it1 )
    {
        MnemonicConversion &mc = it1->second;
        const char *format  = mc.x86;
        ParameterPattern pp = mc.pp;
        if( mc.nbr_parameters == parameters.size() )
        {
            handled = true;
            std::string parameters_listed;
            bool first = true;
            for( const std::string s: parameters )
            {
                parameters_listed += first ? "" : ",";
                first = false;
                parameters_listed += s;
            }
            switch( pp )
            {
                default:
                {
                    printf( "Error: Unknown parameter pattern, instruction=[%s], line=[%s]\n", instruction.c_str(), line.c_str() );
                    return false;
                }
                case none:
                {
                    x86_out = std::string(format);
                    break;
                }
                case echo:
                {
                    x86_out = util::sprintf( format, parameters_listed.c_str() );
                    break;
                }
                case jnx_around:
                {
                    std::string parm = parameters[0];
                    std::string out, reverse_out;
                    if( is_conditional(parm,out,reverse_out) )
                    {
                        std::string temp = util::sprintf( "skip%d", skip_counter++ );
                        x86_out = util::sprintf( format, reverse_out.c_str(), temp.c_str(), temp.c_str() );
                    }
                    else
                    {
                        printf( "Error: Illegal conditional parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    break;
                }
                case jnx_around_addr:
                {
                    std::string parm = parameters[0];
                    std::string out, reverse_out;
                    if( is_conditional(parm,out,reverse_out) )
                    {
                        std::string temp = util::sprintf( "skip%d", skip_counter++ );
                        x86_out = util::sprintf( format, reverse_out.c_str(), temp.c_str(), parameters[1].c_str(), temp.c_str() );
                    }
                    else
                    {
                        printf( "Error: Illegal conditional parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    break;
                }
                case jx_addr:
                {
                    std::string parm = parameters[0];
                    std::string out, reverse_out;
                    if( is_conditional(parm,out,reverse_out) )
                    {
                        x86_out = util::sprintf( format, out.c_str(), parameters[1].c_str() );
                    }
                    else
                    {
                        printf( "Error: Illegal conditional parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    break;
                }
                case clr_n_parm:
                {
                    std::string parm = parameters[0];
                    std::string out1;
                    if( !is_n_clr(parm,out1) )
                    {
                        printf( "Error: Unknown n parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    parm = parameters[1];
                    std::string out2;
                    if( is_reg8_mem8(parm,out2) )
                        x86_out = util::sprintf( format, out2.c_str(), out1.c_str() );     // note reverse order
                    else
                    {
                        printf( "Error: Illegal parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    break;
                }
                case set_n_parm:
                {
                    std::string parm = parameters[0];
                    std::string out1;
                    if( !is_n_set(parm,out1) )
                    {
                        printf( "Error: Unknown n parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    parm = parameters[1];
                    std::string out2;
                    if( is_reg8_mem8(parm,out2) )
                        x86_out = util::sprintf( format, out2.c_str(), out1.c_str() );     // note reverse order
                    else
                    {
                        printf( "Error: Illegal parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    break;
                }
                case parm_8_more:
                {
                    // _more means this one might not be the correct handler, if it's not
                    //   we continue
                    handled = false;
                    std::string parm = parameters[0];
                    std::string out;
                    if( is_reg8_mem8(parm,out) )
                    {
                        x86_out = util::sprintf( format, out.c_str() );
                        handled = true;
                    }
                    break;
                }
                case parm_16:
                {
                    std::string parm = parameters[0];
                    std::string out;
                    if( is_reg16_mem16(parm,out) )
                        x86_out = util::sprintf( format, out.c_str() );
                    else
                    {
                        printf( "Error: Illegal parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    break;
                }
                case dst_src:
                {
                    std::string parm1 = parameters[0];
                    std::string parm2 = parameters[1];
                    std::string out1, out2;
                    AddressMode gt1, gt2;
                    if( !is_generic(parm1,out1,gt1) )
                    {
                        printf( "Error: Unknown parameter, line=[%s]\n", line.c_str() );
                        return false;
                    }
                    if( !is_generic(parm2,out2,gt2) )
                    {
                        printf( "Error: Unknown parameter, line=[%s]\n", line.c_str() );
                        return false;
                    }
                    if( gt1 == am_mem )
                        out1 = (gt2==am_reg16?"word ":"byte ") + out1;
                    if( gt2 == am_mem )
                        out2 = (gt1==am_reg16?"word ":"byte ") + out2;
                    x86_out = util::sprintf( format, out1.c_str(), out2.c_str() );
                    std::string fixups = util::toupper(x86_out);
                    if( fixups == "MOV\tAL,R" )
                        x86_out = "Z80_LDAR";
                    else if( fixups == "XCHG\tDX,BX" )
                        x86_out = "XCHG\tbx,dx";
                    break;
                }
                case dst_src_8_more:
                {
                    // _more means this one might not be the correct handler, if it's not
                    //   we continue
                    handled = false;
                    std::string parm1 = parameters[0];
                    std::string parm2 = parameters[1];
                    std::string out1, out2;
                    AddressMode gt1, gt2;
                    if( is_generic(parm1,out1,gt1) )
                    {
                        if( is_generic(parm2,out2,gt2) )
                        {
                            if( gt1==am_reg8 || gt2==am_reg8 )
                            {
                                if( gt1 == am_mem )
                                    out1 = "byte " + out1;
                                if( gt2 == am_mem )
                                    out2 = "byte " + out2;
                                x86_out = util::sprintf( format, out1.c_str(), out2.c_str() );
                                handled = true;
                            }
                        }
                    }
                    break;
                }
                case dst_src_16:
                {
                    std::string parm1 = parameters[0];
                    std::string parm2 = parameters[1];
                    std::string out1, out2;
                    AddressMode gt1, gt2;
                    if( !is_generic(parm1,out1,gt1) )
                    {
                        printf( "Error: Unknown parameter, line=[%s]\n", line.c_str() );
                        return false;
                    }
                    if( !is_generic(parm2,out2,gt2) )
                    {
                        printf( "Error: Unknown parameter, line=[%s]\n", line.c_str() );
                        return false;
                    }
                    if( gt1==am_reg8 || gt2==am_reg8 )
                    {
                        printf( "Error: Unknown parameter, line=[%s]\n", line.c_str() );
                        return false;
                    }
                    if( gt1 == am_mem )
                        out1 = "word " + out1;
                    if( gt2 == am_mem )
                        out2 = "word " + out2;
                    x86_out = util::sprintf( format, out1.c_str(), out2.c_str() );
                    break;
                }
                case af_af_dash_more:
                {
                    // _more means this one might not be the correct handler, if it's not
                    //   we continue
                    handled = false;
                    std::string parm1 = util::toupper(parameters[0]);
                    std::string parm2 = util::toupper(parameters[1]);
                    if( parm1 == "AF" && parm2 == "AF'" )
                    {
                        x86_out = std::string(format);
                        handled = true;
                    }
                    break;
                }
                case push_parameter:
                {
                    std::string parm = util::toupper(parameters[0]);
                    std::string out;
                    if( parm == "AF" )
                        x86_out = "LAHF\n\tPUSH\teax";
                    else if( is_reg16(parm,out) )
                        x86_out = util::sprintf( "PUSH\te%s", out.c_str() );
                    else
                    {
                        printf( "Error: Illegal push parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    break;
                }
                case pop_parameter:
                {
                    std::string parm = util::toupper(parameters[0]);
                    std::string out;
                    if( parm == "AF" )
                        x86_out = "POP\teax\n\tSAHF";
                    else if( is_reg16(parm,out) )
                        x86_out = util::sprintf( "POP\te%s", out.c_str() );
                    else
                    {
                        printf( "Error: Illegal pop parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    break;
                }
                case reg8:
                {
                    std::string parm = parameters[0];
                    std::string out;
                    if( is_reg8(parm,out) )
                        x86_out = util::sprintf( format, out.c_str() );
                    else
                    {
                        printf( "Error: Unknown reg8 parameter %s, line=[%s]\n", parm.c_str(), line.c_str() );
                        return false;
                    }
                    break;
                }
            }
        }
    }
    if( !handled )
        printf( "Error: No match for instruction with %d parameters, instruction=[%s], line=[%s]\n", parameters.size(), instruction.c_str(), line.c_str() );
    return handled;
}


void define_opcode( const std::string &opcode, const MnemonicConversion &mc )
{
    xlat.insert( std::make_pair(opcode, mc) );
}

void translate_init()
{
    //
    // Move
    //

    // LD dst,src -> MOV dst,src
    define_opcode( "LD", { "MOV\t%s,%s",  2, dst_src } );

    //
    // Push and pop
    //

    // PUSH reg16 -> PUSH reg32
    // PUSH AF    -> LAHF; PUSH AX
    define_opcode( "PUSH", { "%s", 1, push_parameter } );

    // POP reg16 -> POP reg32
    // POP AF    -> POP AX; SAHF
    define_opcode( "POP", { "%s", 1, pop_parameter } );

    //
    // Arithmetic and logic
    //

    // ADD dst,src      -> ADD dst,src
    define_opcode( "ADD", { "ADD\t%s,%s", 2, dst_src_8_more } );
    define_opcode( "ADD", { "LAHF\n\tADD\t%s,%s\n\tSAHF", 2, dst_src_16 } );

    // AND a,imm8      -> AND dst,src
    define_opcode( "AND", { "AND\t%s,%s", 2, dst_src } );

    // SUB dst,src      -> SUB dst,src
    define_opcode( "SUB", { "SUB\t%s,%s", 2, dst_src_8_more } );
    define_opcode( "SUB", { "LAHF\n\tSUB\t%s,%s\n\tSAHF", 2, dst_src_16 } );
    define_opcode( "SBC", { "SBB\t%s,%s", 2, dst_src_16 } );

    // XOR dst,src      -> XOR dst,src
    define_opcode( "XOR", { "XOR\t%s,%s", 2, dst_src } );

    // CP dst,src      -> CMP src,dst
    define_opcode( "CP", { "CMP\t%s,%s", 2, dst_src } );

    // DEC parm      -> DEC parm
    define_opcode( "DEC", { "DEC\t%s", 1, parm_8_more } );
    define_opcode( "DEC", { "LAHF\n\tDEC\t%s\n\tSAHF", 1, parm_16 } );

    // INC parm      -> INC parm
    define_opcode( "INC", { "INC\t%s", 1, parm_8_more } );
    define_opcode( "INC", { "LAHF\n\tINC\t%s\n\tSAHF", 1, parm_16 } );

    //
    // Bit test, set, clear
    //

    // BIT n,parm -> TEST parm,mask(n) # but damages other flags
    define_opcode( "BIT", { "TEST\t%s,%s", 2, set_n_parm } );

    // SET n,parm -> LAHF; OR parm,mask[n]; SAHF
    define_opcode( "SET", { "LAHF\n\tOR\t%s,%s\n\tSAHF", 2, set_n_parm } );

    // RES n,parm -> LAHF; AND parm,not mask[n]; SAHF
    define_opcode( "RES", { "LAHF\n\tAND\t%s,%s\n\tSAHF", 2, clr_n_parm } );

    //
    // Rotate and Shift
    //

    /*
      Rotate and shift reference info

              8080 (ext)               Z80                              X86
              ----                     ---                              ---
              RLC  (rotate A left)     RLCA                             ROL al,1
              RLCR reg (ext)           RLC reg *                        ROL reg,1
              RAL  (RL thru CY)        RLA                              RCL al,1
              RALR reg (ext)           RL reg *                         RCL reg,1
              RRC  (rotate A right)    RRCA                             ROR al,1
              RRCR reg (ext)           RRC reg  *                       ROR reg,1
              RAR  (RR thru CY)        RRA                              RCR al,1
              RARR reg (ext)           RR reg *                         RCR reg,1
              SRLR reg (ext)           SRL reg (shift right logical) ^  SHR reg,1  (shift right)
              SRAR reg (ext)           SRA reg (shift right arithmetic) SAR reg,1  (shift arithmetic right)
              SLAR reg (ext)           SLA reg (shift left arithmetic)  SAL reg,1  (or SHL reg,1)
              RLD (ext)                RLD (rotate BCD digit left)      - 
              RRD (ext)                RRD (rotate BCD digit right)     -

              The (ext) instructions here are not present at all in the actual
              8080, but these mnemonics are 8080 style extensions for the Z80
              in the TDL macro assembler used for the original Sargon source

              * RLC stands for "Rotate Left Circular", the CY bit is set to
                reflect the bit rotated from bit 7 to bit 0. Also RLC A (etc)
                is not quite a two byte equivalent to the one byte original
                8080 instruction set RLCA because it affects the flags differently

              ^ arithmetic right shifts copy bit 7, logic right shifts clear it
                arithmetic and logic left shifts are the same, clearing bit 0
                for X86 'shift' = shift logical (logical is assumed) and both
                forms of left shifts are allowed, as synonyms.

    */

    // Only implement the instructions that are present in the Sargon source code

    // RLA -> RCL al,1             # rotate left through CY
    define_opcode( "RLA", { "RCL\tal,1",  0, none } );

    // RR reg8 -> RCR reg, 1     # rotate right through CY
    define_opcode( "RR",  { "RCR\t%s,1", 1, reg8 } );

    // RLD -> macro or call; 12 bits of low AL and byte [BX] rotated 4 bits left (!!)
    define_opcode( "RLD", { "Z80_RLD", 0, none } );

    // RRD -> macro or call; 12 bits of low AL and byte [BX] rotated 4 bits right (!!)
    define_opcode( "RRD", { "Z80_RRD", 0, none } );

    // SLA reg8 -> SHL reg8,1     # left shift into CY, bit 0 zeroed (arithmetic and logical are the same)
    define_opcode( "SLA", { "SHL\t%s,1", 1, reg8 } );

    // SRA reg8 -> SAR reg8,1     # arithmetic right shift into CY, bit 7 preserved
    define_opcode( "SRA", { "SAR\t%s,1", 1, reg8 } );

    // SRL reg8 -> SHR reg8,1     # logical right shift into CY, bit 7 zeroed
    define_opcode( "SRL", { "SHR\t%s,1", 1, reg8 } );

    //
    // Calls, returns, jumps
    //

    /*

      Conditional branches reference info

      There is an excellent X86 Jump reference at www.unixwiz.net/techtips/x86-jumps.html
      that explains all the X86 synonyms. For our purposes only S=1, S=0 are potential
      hazards, and I did indeed handle these wrongly first time through

      The Z80 has both JP and JR instructions. The JR (R=relative) instructions are only
      two bytes. The JR instruction is restricted to unconditional or C,NC,Z and NZ
      conditionals only.

      The X86 does not allow conditional calls or returns, and the assembler determines
      whether to use short/long relative/absolute operands.

              8080                     Z80                        X86
              ----                     ---                        ---
     C=1      C  (JC, RC, CC)          C  (JP C, RET C, CALL C)   C  (JC)
     C=0      NC                       NC                         NC
     Z=1      Z                        Z                          Z
     Z=0      NZ                       NZ                         NZ
     S=1      M                        M                          S
     S=0      P                        P                          NS
     P=1      PE                       PE                         PE
     P=0      PO                       PO                         PO

    */

    // CALL addr -> CALL addr
    define_opcode( "CALL", { "CALL\t%s", 1, echo } );

    // CALL c,addr -> Jnx temp; CALL addr; temp:
    define_opcode( "CALL", { "J%s\t%s\n\tCALL\t%s\n%s:", 2, jnx_around_addr } );

    // CALL addr -> CALL addr
    define_opcode( "RET", { "RET", 0, none } );

    // RET c -> Jnx temp; RET; temp:
    define_opcode( "RET", { "J%s\t%s\n\tRET\n%s:", 1, jnx_around } );

    // DJNZ addr -> LAHF; DEC ch; JNZ addr; SAHF; ## flags affected at addr (sadly not much to be done)
    define_opcode( "DJNZ", { "LAHF\n\tDEC\tch\n\tJNZ\t%s\n\tSAHF", 1, echo } );

    // JR addr -> JMP addr
    define_opcode( "JR", { "JMP\t%s", 1, echo } );

    // JP addr -> JMP addr
    define_opcode( "JP", { "JMP\t%s", 1, echo } );

    // JR c,addr -> Jx addr
    define_opcode( "JR", { "J%s\t%s", 2, jx_addr } );

    // JP c,addr -> Jx addr
    define_opcode( "JP", { "J%s\t%s", 2, jx_addr } );


    //
    // Miscellaneous
    //

    // NEG -> NEG al
    define_opcode( "NEG", { "NEG\tal",  0, none } );

    // EX af,af'-> macro
    define_opcode( "EX", { "Z80_EXAF", 2, af_af_dash_more } );

    // EX de,hl -> XCHG ebx,edx
    define_opcode( "EX", { "XCHG\t%s,%s", 2, dst_src } );

    // EXAF -> macro
    define_opcode( "EXAF", { "Z80_EXAF", 0, none } );

    // EXX -> macro
    define_opcode( "EXX", { "Z80_EXX", 0, none } );

    // LDAR -> Load A with incrementing R (RAM refresh) register (to get a random number)
    define_opcode( "LDAR", { "Z80_LDAR",  0, none } );

    // CPIR -> macro/call
    define_opcode( "CPIR", { "Z80_CPIR", 0, none } );

    //
    // Macros
    //

    //
    // Directives
    //
    define_opcode( "DS", { "DB\t%s DUP (?)", 1, echo } );
    define_opcode( "DB", { "DB\t%s", 1, echo } );
    define_opcode( "DW", { "DD\t%s", 1, echo } );
    define_opcode( "ORG", { ";ORG\t%s", 1, echo } );
 }

 // Optionally replace the LAHF/SAHF versions - don't really need to preserve flags in these
 //  instructions in Sargon
void translate_init_slim_down()
{
}

