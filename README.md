# WordSymphony
WordSymphony is an R script that generates customizable word clouds and radial bar plots from PDF/TXT/DOCX/HTML files. It supports various output formats, including PDF, PNG, and interactive HTML, and offers extensive options for tailoring the appearance and content of the visualizations.

## Dependencies
The script relies on the following R packages, which will be installed automatically if missing:
- `optparse`, `dplyr`, `readr`, `forcats`, `stringr`, `ggplot2`, `tibble`, `lubridate`, `tidyr`, `purrr`, `tidytext`, `textreadr`, `ggwordcloud`, `wordcloud2`, `htmlwidgets`, `pdftools`, `png`, `udpipe`, `RColorBrewer`

## Installation
1. Ensure R is installed on your system (version 4.0 or higher recommended).
2. Clone this repository:
   ```bash
   git clone https://github.com/oliveira-lab/wordsymphony.git
   cd wordsymphony   
3. Command-line options
   ```TXT
   -d, --dir: Input directory containing text files.
   -f, --files: Comma-separated list of text files (e.g., file1.txt,file2.pdf,file3.html).
   -o, --output: Output file name with extension .pdf, .png, or .html (default: wordcloud.pdf).
   --min_freq: Minimum frequency for words to be included (default: 5).
   --max_words: Maximum number of words in the cloud (default: 100).
   --stop_words_file: Path to a file with additional stop words (one per line).
   --shape: Shape of the word cloud (e.g., circle, cardioid, diamond).
   --colors: Color palette (e.g., Set1, Blues), comma-separated colors (e.g., red,blue,green), or a single color (e.g., black).
   --rotation: Rotate words randomly (TRUE/FALSE).
   --min_rotation: Minimum rotation angle in degrees (e.g., -45).
   --max_rotation: Maximum rotation angle in degrees (e.g., 45).
   --bg_color: Background color of the plot (e.g., white, black, #RRGGBB).
   --font_family: Font family for words (e.g., sans, serif, mono).
   --unwanted_words: Comma-separated list of words to exclude (e.g., word1,word2).
   --pos_tags: Comma-separated list of POS tags to include (e.g., NOUN,VERB,ADJ).
4. Run it as:
   ```bash
   Rscript wordsymphony.R --files dummy_text.txt --bg_color black

## Output
Two PDF files respectively named wordcloud.pdf and wordcloud_radial.pdf.

![Output wordsymphony](/test/wordcloud.pdf. "Word cloud for the dummy_text.txt")
![Output wordsymphony](/test/wordcloud_radial.pdf. "Radial word frequency graph")   

## License and citing
This project is licensed under a GPL-3.0 License. See the LICENSE file for details. Please cite MuSiMa by including the link to https://github.com/oliveira-lab/wordsymphony.git.

