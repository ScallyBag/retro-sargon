/*

  This program tests a Windows port of the classic program Sargon, as
  presented in the book "Sargon a Z80 Computer Chess Program" by Dan and
  Kathe Spracklen (Hayden Books 1978). Another program in this suite converts
  the Z80 code to working X86 assembly language. A third program wraps the
  Sargon X86 code in a simple standard Windows UCI engine interface.
  
  */

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <algorithm>
#include "util.h"
#include "thc.h"
#include "sargon-asm-interface.h"
#include "sargon-interface.h"

// Misc
struct Position;
static void build_model( const std::vector<Position> &model );
static void new_test();
static std::string get_key();

// Nodes to track the PV (principal [primary?] variation)
struct NODE
{
    unsigned int level;
    unsigned char from;
    unsigned char to;
    unsigned char flags;
    unsigned char value;
    NODE() : level(0), from(0), to(0), flags(0), value(0) {}
    NODE( unsigned int l, unsigned char f, unsigned char t, unsigned char fs, unsigned char v ) : level(l), from(f), to(t), flags(fs), value(v) {}
};
static std::vector< NODE > nodes;

// Control callback() behaviour
static bool callback_enabled;
static bool callback_kingmove_suppressed;
static int callback_verbosity;

int main( int argc, const char *argv[] )
{
    new_test();
    return 0;
}

// Data structures to track the 15 positions in minimax example
static std::map<std::string,unsigned int> values;
static std::map<std::string,unsigned int> cardinal_nbr;
static std::map<std::string,std::string> lines;
static std::map<std::string,double> scores;

struct Position
{
    std::string key;
    std::string moves;
    double score;
};

// White can take a bishop or fork king queen and rook
static std::vector<Position> model1 =
{
   { "(root)", "7k/R1ppp1p1/1p6/4q3/5N1r/3b3P/PP3PP1/Q5K1 w - - 0 1",  0.0},
   { "A"     , "1.Nxd3",                0.0  },
   { "AG"    , "1.Nxd3 Qd6",            0.0  },
   { "AGA"   , "1.Nxd3 Qd6 2.Ne1",      3.3  },    // White wins a bishop
   { "AGB"   , "1.Nxd3 Qd6 2.Qb1",      3.0  },    // White wins a bishop
   { "AH"    , "1.Nxd3 Qg5",            0.0  },
   { "AHA"   , "1.Nxd3 Qg5 2.Rxc7",     3.1  },    // White wins a bishop
   { "AHB"   , "1.Nxd3 Qg5 2.Kh2",      3.2  },    // White wins a bishop
   { "B"     , "1.Ng6+",                0.0  },
   { "BG"    , "1.Ng6+ Kh7",            0.0  },
   { "BGA"   , "1.Ng6+ Kh7 2.Nxe5",     9.2  },    // White wins a queen
   { "BGB"   , "1.Ng6+ Kh7 2.Nxh4",     5.0  },    // White wins a rook
   { "BH"    , "1.Ng6+ Kg8",            0.0  },
   { "BHA"   , "1.Ng6+ Kg8 2.Nxe5",     9.0  },    // White wins a queen
   { "BHB"   , "1.Ng6+ Kg8 2.Nxh4",     5.2  }     // White wins a rook
};

// White can give Philidor's mate, or defend
static std::vector<Position> model2 =
{
    { "(root)", "1rr4k/4n1pp/7N/8/8/8/Q4PPP/6K1 w - - 0 1", 0.0 },
    { "A"     , "1.Qg8+",               0.0   },
    { "AG"    , "1.Qg8+ Nxg8",          0.0   },
    { "AGA"   , "1.Qg8+ Nxg8 2.Nf7#",   12.0  },   // White gives mate
    { "AGB"   , "1.Qg8+ Nxg8 2.Nxg8",   -10.0 },   // Black has huge material plus
    { "AH"    , "1.Qg8+ Rxg8",          0.0   },
    { "AHA"   , "1.Qg8+ Rxg8 2.Nf7#",   12.0  },   // White gives mate
    { "AHB"   , "1.Qg8+ Rxg8 2.Nxg8",   -8.0  },   // Black has large material plus
    { "B"     , "1.Qa1",                0.0   },
    { "BG"    , "1.Qa1 Rc6",            0.0   },
    { "BGA"   , "1.Qa1 Rc6 2.Nf7+",     0.0   },   // equal(ish)
    { "BGB"   , "1.Qa1 Rc6 2.Ng4",      0.0   },   // equal(ish)
    { "BH"    , "1.Qa1 Ng8",            0.0   },
    { "BHA"   , "1.Qa1 Ng8 2.Nf7#",     12.0  },   // White gives mate
    { "BHB"   , "1.Qa1 Ng8 2.Ng4",      0.0   }    // equal(ish)
};

// White can give defend or give Philidor's mate (same as above, with
//  first move reversed)
static std::vector<Position> model3 =
{
    { "(root)", "1rr4k/4n1pp/7N/8/8/8/Q4PPP/6K1 w - - 0 1", 0.0 },
    { "A"     , "1.Qa1",                0.0   },
    { "AG"    , "1.Qa1 Rc6",            0.0   },
    { "AGA"   , "1.Qa1 Rc6 2.Nf7+",     0.0   },   // equal(ish)
    { "AGB"   , "1.Qa1 Rc6 2.Ng4",      0.0   },   // equal(ish)
    { "AH"    , "1.Qa1 Ng8",            0.0   },
    { "AHA"   , "1.Qa1 Ng8 2.Nf7#",     12.0  },   // White gives mate
    { "AHB"   , "1.Qa1 Ng8 2.Ng4",      0.0   },   // equal(ish)
    { "B"     , "1.Qg8+",               0.0   },
    { "BG"    , "1.Qg8+ Nxg8",          0.0   },
    { "BGA"   , "1.Qg8+ Nxg8 2.Nf7#",   12.0  },   // White gives mate
    { "BGB"   , "1.Qg8+ Nxg8 2.Nxg8",   -10.0 },   // Black has huge material plus
    { "BH"    , "1.Qg8+ Rxg8",          0.0   },
    { "BHA"   , "1.Qg8+ Rxg8 2.Nf7#",   12.0  },   // White gives mate
    { "BHB"   , "1.Qg8+ Rxg8 2.Nxg8",   -8.0  }    // Black has large material plus
};

// White can win a rook, or give mate in some lines
static std::vector<Position> model4 =
{
    { "(root)", "8/r5kp/6pr/8/1n1N4/6R1/6PP/3R3K w - - 0 1", 0.0 },
    { "A"     , "1.Nf5+",               0.0  },
    { "AG"    , "1.Nf5+ Kh8",           0.0  },
    { "AGA"   , "1.Nf5+ Kh8 2.Nxh6",    5.0  },    // White wins a rook
    { "AGB"   , "1.Nf5+ Kh8 2.Rd8#",    12.0 },    // White gives mate
    { "AH"    , "1.Nf5+ Kg8",           0.0  },
    { "AHA"   , "1.Nf5+ Kg8 2.Nxh6+",   5.1  },    // White wins a rook
    { "AHB"   , "1.Nf5+ Kg8 2.h3",      0.1  },    // equal(ish)
    { "B"     , "1.Ne6+",               0.0  },
    { "BG"    , "1.Ne6+ Kh8",           0.0  },
    { "BGA"   , "1.Ne6+ Kh8 2.h3",      0.2  },    // equal(ish)
    { "BGB"   , "1.Ne6+ Kh8 2.Rd8#",    12.0 },    // White gives mate
    { "BH"    , "1.Ne6+ Kg8",           0.0  },
    { "BHA"   , "1.Ne6+ Kg8 2.h3",      0.3  },    // equal(ish)
    { "BHB"   , "1.Ne6+ Kg8 2.Rd8+",    0.5  }     // equal(ish)
};

static void build_model( const std::vector<Position> &model )
{
    cardinal_nbr["(root)"]  = 0;
    cardinal_nbr["A"]       = 1;
    cardinal_nbr["B"]       = 2;
    cardinal_nbr["AG"]      = 3;
    cardinal_nbr["AH"]      = 4;
    cardinal_nbr["AGA"]     = 5;
    cardinal_nbr["AGB"]     = 6;
    cardinal_nbr["AHA"]     = 7;
    cardinal_nbr["AHB"]     = 8;
    cardinal_nbr["BG"]      = 9;
    cardinal_nbr["BH"]      = 10;
    cardinal_nbr["BGA"]     = 11;
    cardinal_nbr["BGB"]     = 12;
    cardinal_nbr["BHA"]     = 13;
    cardinal_nbr["BHB"]     = 14;
    thc::ChessPosition cp;
    const char *fen = model[0].moves.c_str();
    cp.Forsyth( fen );
    printf( "Initial position is %s\n", cp.ToDebugStr().c_str() );
    bool skip=true; // skip the first
    for( Position pos: model )
    {
        lines[pos.key]  = pos.moves;
        scores[pos.key] = pos.score;
        values[pos.key] = sargon_import_value(pos.score); 
    }
    lines["(root)"]  = "(root)";    // Because we used this one for the FEN
}


// Calculate a short string key to represent the moves played
//  eg 1. a4-a5 h6-h5 2. a5-a6 => "AHA"
static std::string get_key()
{
    thc::ChessPosition cp;
    sargon_export_position( cp );
    std::string key = "??";
    int nmoves = 0; // work out how many moves have been played
    bool a0 = (cp.squares[thc::a3] == 'P');
    bool a1 = (cp.squares[thc::a4] == 'P');
    bool a2 = (cp.squares[thc::a5] == 'P');
    if( a1 )
        nmoves += 1;
    else if( a2 )
        nmoves += 2;
    bool b0 = (cp.squares[thc::b4] == 'P');
    bool b1 = (cp.squares[thc::b5] == 'P');
    bool b2 = (cp.squares[thc::b6] == 'P');
    if( b1 )
        nmoves += 1;
    else if( b2 )
        nmoves += 2;
    bool g0 = (cp.squares[thc::g6] == 'p');
    bool g1 = (cp.squares[thc::g5] == 'p');
    if( g1 )
        nmoves += 1;
    bool h0 = (cp.squares[thc::h6] == 'p');
    bool h1 = (cp.squares[thc::h5] == 'p');
    if( h1 )
        nmoves += 1;
    if( nmoves == 0 )
    {
        key = "(root)";
    }
    else if( nmoves == 1 )
    {
        if( a1 )
            key = "A";
        else if( b1 )
            key = "B";
    }
    else if( nmoves == 2 )
    {
        if( a1 && g1 )
            key = "AG";
        else if( a1 && h1 )
            key = "AH";
        else if( b1 && g1  )
            key = "BG";
        else if( b1 && h1 )
            key = "BH";
    }
    else if( nmoves == 3 )
    {
        if( a2 && g1 )
            key = "AGA";
        else if( a2 && h1 )
            key = "AHA";
        else if( b2 && g1 )
            key = "BGB";
        else if( b2 && h1 )
            key = "BHB";
        else
        {
            // In other three move cases we can't work out the whole sequence of moves unless we know
            //  the last move, try to rely on this as little as possible
            unsigned int p = peekw(MLPTRJ);  // Load ptr to last move
            unsigned char from  = p ? peekb(p+2) : 0;
            thc::Square sq_from;
            bool ok_from = sargon_export_square(from,sq_from);
            if( ok_from )
            {
                bool a_last = (thc::get_file(sq_from) == 'a');
                bool b_last = (thc::get_file(sq_from) == 'b');
                bool g_last = (thc::get_file(sq_from) == 'g');
                bool h_last = (thc::get_file(sq_from) == 'h');
                if( a1 && g1 && b1 )
                {
                    if ( a_last )
                        key = "BGA";
                    else if ( b_last )
                        key = "AGB";
                }
                else if( a1 && h1 && b1 )
                {
                    if ( a_last )
                        key = "BHA";
                    else if ( b_last )
                        key = "AHB";
                }
            }
        }
    }
    return key;
}

// Use a simple example to explore/probe the minimax algorithm and verify it
static void new_test()
{
    // White king on a1 pawns a4,b3 Black king on h8 pawns g6,h6 we are going
    //  to use this very dumb position to probe Alpha Beta pruning etc. (we
    //  will kill the kings so that each side has only two moves available
    //  at each position).
    // (Start 'a' pawn on a4 instead of a3 so that 'a' pawn move is generated
    // first on White's second move, even if 'b' pawn advances on first move)
    const char *pos_probe = "7k/8/6pp/8/1P6/P7/8/K7 w - - 0 1";

    // Because there are only 2 moves available at each ply, we can explore
    //  to PLYMAX=3 with only 2 positions at ply 1, 4 positions at ply 2
    //  and 8 positions at ply 3 (plus 1 root position at ply 0) for a very
    //  manageable 1+2+4+8 = 15 nodes (i.e. positions) total. We use the
    //  callback facility to monitor the algorithm and indeed actively
    //  interfere with it by changing the node evals and watching how that
    //  effects node traversal and generates a best move.
    build_model(model3);
    callback_enabled = true;
    callback_kingmove_suppressed = true;
    callback_verbosity = 2;
    thc::ChessPosition cp;
    cp.Forsyth(pos_probe);
    pokeb(MLPTRJ,0); //need to set this ptr to 0 to get Root position recognised in callback()
    pokeb(MLPTRJ+1,0);
    pokeb(KOLOR,0);
    pokeb(PLYMAX,3);
    sargon(api_INITBD);
    sargon_import_position(cp);
    sargon(api_ROYALT);
    pokeb(MOVENO,3);    // Move number is 1 at at start, add 2 to avoid book move
    nodes.clear();
    sargon(api_CPTRMV);
}

extern "C" {
    void callback( uint32_t reg_edi, uint32_t reg_esi, uint32_t reg_ebp, uint32_t reg_esp,
                   uint32_t reg_ebx, uint32_t reg_edx, uint32_t reg_ecx, uint32_t reg_eax,
                   uint32_t reg_eflags )
    {
        uint32_t *sp = &reg_edi;
        sp--;

        // expecting code at return address to be 0xeb = 2 byte opcode, (0xeb + 8 bit relative jump),
        uint32_t ret_addr = *sp;
        const unsigned char *code = (const unsigned char *)ret_addr;
        const char *msg = (const char *)(code+2);   // ASCIIZ text should come after that

        if( 0 == strcmp(msg,"LDAR") )
        {
            // For testing purposes, make LDAR output increment, results in
            //  deterministic choice of book moves
            static uint8_t a_reg;
            a_reg++;
            volatile uint32_t *peax = &reg_eax;
            *peax = a_reg;
            return;
        }
        else if( 0 == strcmp(msg,"Yes! Best move") )
        {
            unsigned int  p     = peekw(MLPTRJ);
            unsigned int  level = peekb(NPLY);
            unsigned char from  = peekb(p+2);
            unsigned char to    = peekb(p+3);
            unsigned char flags = peekb(p+4);
            unsigned char value = peekb(p+5);
            NODE n(level,from,to,flags,value);
            nodes.push_back(n);
        }
        if( !callback_enabled )
            return;

        // For purposes of minimax tracing experiment, we only want two possible
        //  moves in each position - achieved by suppressing King moves
        if( callback_kingmove_suppressed && std::string(msg) == "Suppress King moves" )
        {
            unsigned char piece = peekb(T1);
            if( piece == 6 )    // King?
            {
                // Change al to 2 and ch to 1 and MPIECE will exit without
                //  generating (non-castling) king moves
                volatile uint32_t *peax = &reg_eax;
                *peax = 2;
                volatile uint32_t *pecx = &reg_ecx;
                *pecx = 0x100;
            }
        }

        // For purposes of minimax tracing experiment, we inject our own points
        //  score for each known position (we keep the number of positions to
        //  managable levels.)
        else if( callback_kingmove_suppressed && std::string(msg) == "end of POINTS()" )
        {
            std::string key = get_key();
            printf( "Position %d, \"%s\" created in tree\n", cardinal_nbr[key], lines[key].c_str() );
            unsigned int value = values[key];
            volatile uint32_t *peax = &reg_eax;     // note use of volatile keyword
            *peax = value;                          // MODIFY VALUE !
        }

        // For purposes of minimax tracing experiment, try to figure out
        //  best move calculation
        else if( callback_verbosity>0 && std::string(msg) == "Alpha beta cutoff?" )
        {
            std::string key = get_key();

            // Eval takes place after undoing last move, so need to add it back to
            //  show position meaningfully
            unsigned int  p     = peekw(MLPTRJ);
            unsigned char from  = peekb(p+2);
            thc::Square sq;
            sargon_export_square(from,sq);
            char c = thc::get_file(sq);
            if( key == "(root)" )
                key = "";
            key += toupper(c); 
            printf( "Eval (ply %d), %s\n", peekb(NPLY), lines[key].c_str() );
            if( callback_verbosity > 1 )
            {
                unsigned int al  = reg_eax&0xff;
                unsigned int bx  = reg_ebx&0xffff;
                unsigned int val = peekb(bx);
                bool jmp = (al <= val);   // Note that Sargon integer values have reverse sense to
                                          //  float centipawns.
                                          //  So jmp if al <= val means
                                          //     jmp if float(al) >= float(val)
                std::string float_value = (val==0 ? "MAX" : util::sprintf("%.1f",sargon_export_value(val)) ); // Show "MAX" instead of "12.8"
                if( jmp )
                {
                    printf( "Alpha beta cutoff because move value=%.1f >= two lower ply value=%s\n",
                    sargon_export_value(al),
                    float_value.c_str() );
                }
                else
                {
                    printf( "No alpha beta cutoff because move value=%.1f < two lower ply value=%s\n",
                    sargon_export_value(al),
                    float_value.c_str() );
                }
            }
        }
        else if( callback_verbosity>1 && std::string(msg) == "No. Best move?" )
        {
            unsigned int al  = reg_eax&0xff;
            unsigned int bx  = reg_ebx&0xffff;
            unsigned int val = peekb(bx);
            bool jmp = (al <= val);   // Note that Sargon integer values have reverse sense to
                                      //  float centipawns.
                                      //  So jmp if al <= val means
                                      //     jmp if float(al) >= float(val)
            std::string float_value = (val==0 ? "MAX" : util::sprintf("%.1f",sargon_export_value(val)) ); // Show "MAX" instead of "12.8"
            if( jmp )
            {
                printf( "Not best move because negated move value=%.1f >= one lower ply value=%s\n",
                sargon_export_value(al),
                float_value.c_str() );
            }
            else
            {
                printf( "Best move because negated move value=%.1f < one lower ply value=%s\n",
                sargon_export_value(al),
                float_value.c_str() );
            }
        }
        else if( callback_verbosity>0 && std::string(msg) == "Yes! Best move" )
        {
            printf( "(Confirming best move)\n" );
        }
    }
};
