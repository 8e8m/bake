/* @BAKE flex -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE @FILE && gcc -std=c99 -ggdb -Wall -Wextra -Wwrite-strings -Wformat -Werror=format-security -fstack-protector-strong -fstack-clash-protection -fcf-protection -fdebug-prefix-map=$PWD=. -Wl,-z,now -O2 -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE -o @SHORT lex.yy.c @ARGS @STOP
   @BAKE flex -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE @FILE && musl-gcc --static -std=c99 -ggdb -Wall -Wextra -Wwrite-strings -Wformat -Werror=format-security -fstack-protector-strong -fstack-clash-protection -fcf-protection -fdebug-prefix-map=$PWD=. -Wl,-z,now -O2 -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE -o @SHORT lex.yy.c @ARGS && cp bake bake-dbg && strip bake @STOP */
/* Licensed under the CC0-1.0. */

%{
#include <ctype.h>

#define CHAR(c)          do { if (stderr2) { fputc(c, stderr2);             } if (g_pipe) { fputc(c, g_pipe);             } } while (0)
#define STRING(s)        do { if (stderr2) { fputs(s, stderr2);             } if (g_pipe) { fputs(s, g_pipe);             } } while (0)
#define FORMAT(...)      do { if (stderr2) { fprintf(stderr2, __VA_ARGS__); } if (g_pipe) { fprintf(g_pipe, __VA_ARGS__); } } while (0)
#define FWRITE(str, len) do { if (stderr2) { fwrite(str, 1, len, stderr2);  } if (g_pipe) { fwrite(str, 1, len, g_pipe);  } } while (0)

FILE * stderr2; // appease musl

#undef ECHO
#define ECHO STRING(yytext)

/* input from main to lexer */
FILE  * g_pipe = NULL, * g_restore, * g_expunge;
int     g_ac, g_select = 1, g_color = 1, g_rm = 0;
char ** g_av, * g_filename, * av0;
/* show additional padding inter and around command? */
int g_skip = 0;
/* for the lexers eyes only */
int line = 1, expunge_depth, first_nl, tmpline;

extern void root(char * filename);
extern void args(int n, int rest);
extern void shorten(char * filename, int n);
%}

SPACE [ \t\r\v\f]
                        /* Everything that can be backslashed */
FILENAME @FILE
CMD      @BAKE[[:space:]]
MACROS   ({CMD}|@STOP|{FILENAME}|@SHORT|@ARGS|@LINE|@RECURS|$@|$*|$+|@\{)

%x FOUND PADDING STOP
%option nodefault noinput nounput noyywrap
%%

\n                    { ++line; }
.|\\@BAKE[[:space:]]  {       ; }

{CMD} { bake:
  static int nth = 0;
  first_nl = 1;
  if (yytext[yyleng-1] == '\n') { ++line;                                                      }
  if (!g_select)                {                                                            ; }
  else if (g_select < 0)        { BEGIN FOUND; fprintf(stderr2, "%s:%d:s%d: ", g_filename, line, ++nth); }
  else if (!--g_select)         { BEGIN FOUND;                                                 }
}

<FOUND>{
 @\{ {
   expunge_depth = 1;
   if (g_select < 0) { ECHO; }
   else if (g_rm && !g_pipe) {
     stderr2 = g_restore;
     g_pipe = g_expunge; STRING("rm '");
   }
 }

 \} {
   if (g_select < 0 || !expunge_depth) { ECHO; break; }
   if (g_rm)           { STRING("'"); return 0; }
   expunge_depth = 0;
 }

 \"                   { g_skip = 1; ECHO;                                                                    }
 '                    { if (g_rm) { STRING("\\'"); } else { g_skip = 1; ECHO; }                              }
 {CMD}|@STOP          { BEGIN INITIAL; yyless(0); if (first_nl) { CHAR('\n'); } if (!g_select) { return 0; } }
 \\\n                 { BEGIN PADDING; ++line; CHAR(' ');                                                    }
 {FILENAME}|$@        { STRING(g_filename);                                                                  }
 @SHORT:[[:digit:]]+  { shorten(g_filename, atoi(strrchr(yytext, ':')+1));                                   }
 @SHORT|$\*           { shorten(g_filename, 1);                                                              }
 @ARGS:[[:digit:]]+   { args(atoi(strrchr(yytext, ':')+1), 0);                                               }
 @ARGS:[[:digit:]]+\+ { args(atoi(strrchr(yytext, ':')+1), 1);                                               }
 @ARGS|$\+            { args(0, 1);                                                                          }
 @LINE                { FORMAT("%d", line);                                                                  }
 @RECURS              { char * prog = realpath(av0, NULL); STRING(prog); free(prog);                         }
 \\{MACROS}           { STRING(yytext + 1);                                                                  }
 {SPACE}              { CHAR(' '); if (!g_skip) { BEGIN PADDING; }                                           }
 \n                   { CHAR('\n'); ++line; if (first_nl) { BEGIN STOP; first_nl = 0; tmpline = 0; }         }
 .|\\'                { ECHO;                                                                                }
}

<PADDING>{
  {SPACE} {                       ; }
  .|\n    { yyless(0); BEGIN FOUND; }
}

<STOP>{
 {CMD} { line += tmpline; goto bake; }
 @STOP { BEGIN FOUND; yyless(0);     }
 \n    { ++tmpline;   yymore();      }
 .|\\@ {              yymore();      }
}

%%

#include <limits.h>
#include <stdarg.h>

# define    RED "\033[91m"
# define  GREEN "\033[92m"
# define YELLOW "\033[93m"
# define    DIM "\033[2m"
# define   BOLD "\033[1m"
# define  RESET "\033[0m"

void root(char * filename) {
  char path[PATH_MAX], * terminator;
  if (!realpath(filename, path)) { return; }
  if ((terminator = strrchr(path, '/'))) {
    *terminator = '\0';
    if(chdir(path)) { abort(); }
  }
}

void args(int n, int rest) {
  if (!rest && n < g_ac) { STRING(g_av[n]); }
  else for (int i = n; i < g_ac; ++i) { STRING(g_av[i]); if (i + 1 < g_ac) { CHAR(' '); } }
}

void shorten(char * filename, int n) {
  char * end = filename + strlen(filename);
  while (n && (end = memrchr(filename, '.', end - filename))) { --n; }
  if (!end) {
    fprintf(stderr2, "%s: Cannot shorten '%s' any further, aborting due to paranoia\n", av0, filename);
    abort();
  }
  FWRITE(filename, end - filename);
}

void help(void) { fprintf(stderr2, g_color ? BOLD "%s" RESET : "%s", "see bake(1) - \"Buy high. Sell low.\"\n"); }

FILE * pipeopen(char * filename, char * mode) {
  FILE * pipe = popen(filename, mode);
  if (!pipe) { fprintf(stderr2, "%s: <pipeopen> %s\n", av0, strerror(errno)); exit(1); }
  return pipe;
}

void print(FILE * fp, char * color_prefix, char * format, ...) {
  va_list ap;
  size_t len = strlen(format);
  g_color ? fprintf(fp, "%s%s: ", color_prefix, av0)
          : fprintf(fp,   "%s: ", av0);
  va_start(ap, format);
  for (size_t i = 0, f = 0; i < len; ++i) {
    if (!(format[i] ^ '\033')) {
      while (format[i] && format[i] != 'm') ++i;
    } else format[f++] = format[i];
  }
  vfprintf(fp, format, ap);
  va_end(ap);
}

int main (int ac, char ** av) {
  int run = 1;
  av0 = av[0];
  stderr2 = fdopen(dup(STDERR_FILENO), "a+");
  FILE * fp, * stderr2_quiet = stderr2;
  /* supports long/short, -allinone, (-X ... -X=... -X<NUM>) */
  while (++av, --ac) {
    size_t i;
    if (av[0][0] != '-') { goto start; }
    if (av[0][1] == '-') {
      if (av[0][2] == '\0')            { ++av, --ac;                       goto start;       }
      if (!strcmp(av[0]+2, "dry-run")) { i = strlen(av[0]);                goto opt_dry_run; }
      /* if (!strcmp(av[0]+2, "color"))   { i = strlen(av[0]);                goto opt_color;   } */
      if (!strcmp(av[0]+2, "expunge")) { i = strlen(av[0]);                goto opt_expunge; }
      if (!strcmp(av[0]+2, "select" )) { if (!(ac-1) || !isdigit(av[1][0])) { goto opt_arg;  }
                                         ++av, --ac; i = strlen(av[0]);    goto opt_select;  }
      if (!strcmp(av[0]+2, "quiet"  )) { i = strlen(av[0]);                goto opt_quiet;   }
      if (!strcmp(av[0]+2, "list"   )) { i = strlen(av[0]);                goto opt_list;    }
      if (!strcmp(av[0]+2, "help"   )) {                                   goto opt_help;    }
      goto opt_default;
    }
    for (i = 1; i < strlen(av[0]); ++i) {
      switch (av[0][i]) {
        opt_dry_run: case 'n': run = 0; break;
          case 's':
          /* Covers cases -<LAST>s<NUM> -<LAST>s <NUM> */
          if (g_select != -1) {
                 if (isdigit(av[0][i+1]))         { g_select = atoi(av[0]+i+1); }
            else if (ac > 1 && isdigit(av[1][0])) { ++av, --ac; opt_select: g_select = atoi(av[0]); }
            else                                  { g_select = 0; }
                 if (!g_select)                   { fprintf(stderr2, "%s: Invalid argument for -s\n", av0); return 1; }
          }
          i = strlen(av[0]);
          break;
        opt_list:    case 'l': run = 0; g_select = -1; break;
        opt_help:    case 'h': help(); return 0;
        opt_quiet:   case 'q': stderr2 = fopen("/dev/null", "w"); if (!stderr2) { stderr2 = stderr2_quiet; perror(av0); return 1; } break;
        /* opt_color:   case 'c': g_color = 0; break; */
        opt_expunge: case 'x': if (g_select > 0) { g_rm = 1; } break;
        opt_default:  default: fprintf(stderr2, "%s: Unknown option '%s'\n", av0, av[0]); return 1;
        opt_arg:               fprintf(stderr2, "%s: Argument missing for '%s'\n", av0, av[0]); return 1;
      }
    }
  }

 start:
  {
    char *no_color = getenv("NO_COLOR");
    if (no_color != NULL && no_color[0] != '\0') { g_color = 0; }
  }
  if (!ac) { fprintf(stderr2, "%s: Missing filename\n", av0); return 1; }
  if (!g_select) { goto out_of_range; }

  g_filename = av[0];
  root(g_filename);

  { /* ensures the filename doesn't have a relative path that would misdirect the command within the new root */
    char * tmp = strrchr(g_filename, '/');
    if (tmp) { g_filename = tmp+1; }
  }

  /* open and prepare ac, av */
  if (!(yyin = fp = fopen(g_filename, "rb")))
  { fprintf(stderr2, g_color ? RED "%s" RESET ": '" BOLD "%s" RESET "' %s\n" : "%s: '%s' %s\n", av0, g_filename, strerror(errno)); return 1; }
  g_ac = --ac, g_av = ++av;

  /* setup pipe and output */

  if (run) {
#define pipeopen(a,b) pipeopen((char*)(a), (char*)(b))
    g_pipe = pipeopen("/bin/sh -e /dev/stdin", "w");
  }
  if (g_rm) {
    g_restore = stderr2;
    g_expunge = g_pipe;
    stderr2 = NULL;
    g_pipe = NULL;
  }
  if (g_select > 0 && stderr2) { fprintf(stderr2, g_color ? GREEN "%s" RESET ": " : "%s: ", av0); fflush(stderr2); }

  yylex(); fflush(stderr2);

  if (g_rm) {
    fputc('\n', g_restore);
    stderr2 = g_restore;
    g_pipe = g_expunge;
  }
  fclose(fp);

  if (g_select > 0) { pclose(g_pipe); goto out_of_range; }

  if (!run) { return 0; }

  if (!g_rm) { fprintf(stderr2, g_color ? GREEN "output" RESET ": " : "output: "); fflush(stderr2); }

  {
    FILE * swap = stderr2 != stderr2_quiet ? stderr2 : NULL;
    stderr2 = stderr2_quiet;

    run = pclose(g_pipe); /* repurposed run */
    if (swap) { fclose(stderr2); stderr2 = swap; }
    if (!g_rm) { fputc('\n', stderr2); }
    if (run < 0) { fprintf(stderr2, "%s: Exit failure\n", av0); }
    if (run > 0) { fprintf(stderr2, "%s: Exit code %d\n", av0, run); }
    return run ? 1 : 0;
    out_of_range: fprintf(stderr2, "%s: <%d> Out of range\n", av0, g_select); return 1;
  }
}
