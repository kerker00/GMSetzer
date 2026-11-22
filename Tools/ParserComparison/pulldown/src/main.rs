// Original GMSetzer development adapter for pulldown-cmark's public API (MIT).
// https://github.com/pulldown-cmark/pulldown-cmark ; pinned in Cargo.toml/lock.
use pulldown_cmark::{html, Parser};
use std::{env, fs, hint::black_box, io::{self, Write}, time::Instant};

fn operation(source: &str, parse: bool) -> usize {
    let parser = Parser::new(black_box(source));
    if parse {
        parser.into_offset_iter().fold(0usize, |sum, (event, range)| {
            black_box(event);
            sum.wrapping_add(range.len() + 1)
        })
    } else {
        let mut output = String::new();
        html::push_html(&mut output, parser);
        black_box(&output);
        output.len()
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = env::args().collect();
    if args.len() != 6 || args[4] != "commonmark" { return Err("invalid arguments".into()); }
    let source = fs::read_to_string(&args[3])?;
    let iterations: usize = args[5].parse()?;
    if !(1..=100_000).contains(&iterations) { return Err("invalid iterations".into()); }
    if args[2] == "emit" {
        let mut output = String::new();
        html::push_html(&mut output, Parser::new(&source));
        io::stdout().write_all(output.as_bytes())?;
    } else {
        if args[2] != "parse" && args[2] != "html" { return Err("unknown mode".into()); }
        let parse = args[2] == "parse";
        for _ in 0..3 { black_box(operation(&source, parse)); }
        let mut observed = 0usize;
        let start = Instant::now();
        for _ in 0..iterations { observed = observed.wrapping_add(operation(&source, parse)); }
        let elapsed = start.elapsed().as_nanos();
        println!("{{\"elapsed_ns\":{elapsed},\"iterations\":{iterations},\"observed\":{observed}}}");
    }
    Ok(())
}
