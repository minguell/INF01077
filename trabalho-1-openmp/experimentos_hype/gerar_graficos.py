#!/usr/bin/env python3
"""Calcula métricas de escalabilidade a partir das medições em CSV."""

import argparse
import csv
import sys
from collections import defaultdict
from html import escape
from pathlib import Path
from statistics import median


REQUIRED_COLUMNS = {
    "version", "input_set", "population", "bits", "generations",
    "mutation_rate", "seed", "threads", "elapsed_seconds",
}
SCRIPT_DIR = Path(__file__).resolve().parent


def slugify(value: str) -> str:
    return "".join(character if character.isalnum() else "_" for character in value).strip("_")


def read_measurements(source: Path):
    with source.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames is None or not REQUIRED_COLUMNS.issubset(reader.fieldnames):
            missing = REQUIRED_COLUMNS - set(reader.fieldnames or [])
            raise ValueError(f"CSV inválido. Colunas ausentes: {', '.join(sorted(missing))}")

        sequential = defaultdict(list)
        parallel = defaultdict(lambda: defaultdict(list))
        metadata = {}
        input_order = []

        for row in reader:
            input_set = row["input_set"]
            signature = tuple(row[key] for key in (
                "population", "bits", "generations", "mutation_rate", "seed"
            ))
            if input_set not in metadata:
                metadata[input_set] = signature
                input_order.append(input_set)
            elif metadata[input_set] != signature:
                raise ValueError(
                    f"O conjunto '{input_set}' possui parâmetros inconsistentes no CSV."
                )

            elapsed = float(row["elapsed_seconds"])
            if elapsed <= 0:
                raise ValueError(f"Tempo inválido no conjunto '{input_set}': {elapsed}")

            if row["version"] == "sequencial":
                sequential[input_set].append(elapsed)
            elif row["version"] == "paralelizado":
                parallel[input_set][int(row["threads"])].append(elapsed)
            else:
                raise ValueError(f"Versão desconhecida: {row['version']}")

    return input_order, metadata, sequential, parallel


def svg_chart(path: Path, title: str, y_label: str, threads, values, ideal, legend):
    """Escreve um gráfico SVG simples sem dependências externas."""
    width, height = 860, 520
    left, right, top, bottom = 95, 35, 70, 80
    chart_width = width - left - right
    chart_height = height - top - bottom
    maximum = max(1.0, *values, *ideal) * 1.10

    def x_position(index):
        if len(threads) == 1:
            return left + chart_width / 2
        return left + index * chart_width / (len(threads) - 1)

    def y_position(value):
        return top + chart_height * (1 - value / maximum)

    def point_list(series):
        return " ".join(
            f"{x_position(index):.2f},{y_position(value):.2f}"
            for index, value in enumerate(series)
        )

    elements = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<style>text { font-family: Arial, sans-serif; fill: #1f2937; } .grid { stroke: #d1d5db; stroke-width: 1; } .axis { stroke: #374151; stroke-width: 1.5; }</style>',
        f'<text x="{width / 2}" y="35" text-anchor="middle" font-size="22" font-weight="bold">{escape(title)}</text>',
    ]

    for tick in range(6):
        value = maximum * tick / 5
        y = y_position(value)
        elements.append(f'<line class="grid" x1="{left}" y1="{y:.2f}" x2="{width - right}" y2="{y:.2f}"/>')
        elements.append(f'<text x="{left - 12}" y="{y + 5:.2f}" text-anchor="end" font-size="13">{value:.2f}</text>')

    elements.extend([
        f'<line class="axis" x1="{left}" y1="{top}" x2="{left}" y2="{height - bottom}"/>',
        f'<line class="axis" x1="{left}" y1="{height - bottom}" x2="{width - right}" y2="{height - bottom}"/>',
        f'<text x="{width / 2}" y="{height - 25}" text-anchor="middle" font-size="16">Número de threads</text>',
        f'<text x="25" y="{height / 2}" text-anchor="middle" font-size="16" transform="rotate(-90 25 {height / 2})">{escape(y_label)}</text>',
    ])

    for index, thread_count in enumerate(threads):
        x = x_position(index)
        elements.append(f'<line class="grid" x1="{x:.2f}" y1="{top}" x2="{x:.2f}" y2="{height - bottom}"/>')
        elements.append(f'<text x="{x:.2f}" y="{height - bottom + 23}" text-anchor="middle" font-size="14">{thread_count}</text>')

    elements.append(f'<polyline points="{point_list(ideal)}" fill="none" stroke="#6b7280" stroke-width="2" stroke-dasharray="7,5"/>')
    elements.append(f'<polyline points="{point_list(values)}" fill="none" stroke="#2563eb" stroke-width="3"/>')
    for index, value in enumerate(values):
        elements.append(f'<circle cx="{x_position(index):.2f}" cy="{y_position(value):.2f}" r="5" fill="#2563eb"/>')

    legend_x = width - right - 190
    elements.extend([
        f'<line x1="{legend_x}" y1="55" x2="{legend_x + 30}" y2="55" stroke="#2563eb" stroke-width="3"/>',
        f'<text x="{legend_x + 38}" y="60" font-size="13">{escape(legend)}</text>',
        f'<line x1="{legend_x}" y1="77" x2="{legend_x + 30}" y2="77" stroke="#6b7280" stroke-width="2" stroke-dasharray="7,5"/>',
        f'<text x="{legend_x + 38}" y="82" font-size="13">Ideal</text>',
        '</svg>',
    ])
    path.write_text("\n".join(elements), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(
        description="Gera gráficos de escalabilidade a partir de tempos.csv."
    )
    parser.add_argument("source", type=Path, help="CSV produzido por executar_testes.sh")
    parser.add_argument(
        "--output-dir", type=Path, default=SCRIPT_DIR / "graficos",
        help="Diretório dos gráficos SVG da Hype (padrão: graficos/)."
    )
    parser.add_argument(
        "--summary-file", type=Path, default=SCRIPT_DIR / "dados" / "resumo.csv",
        help="CSV das medianas e métricas (padrão: dados/resumo.csv)."
    )
    arguments = parser.parse_args()

    if not arguments.source.is_file():
        sys.exit(f"Erro: arquivo não encontrado: {arguments.source}")

    try:
        input_order, metadata, sequential, parallel = read_measurements(arguments.source)
    except (OSError, ValueError) as error:
        sys.exit(f"Erro ao ler medições: {error}")

    arguments.output_dir.mkdir(parents=True, exist_ok=True)
    arguments.summary_file.parent.mkdir(parents=True, exist_ok=True)
    summary_rows = []

    for input_set in input_order:
        if not sequential[input_set]:
            sys.exit(f"Erro: não há medições sequenciais para '{input_set}'.")
        if not parallel[input_set]:
            sys.exit(f"Erro: não há medições paralelas para '{input_set}'.")
        if 1 not in parallel[input_set]:
            sys.exit(
                f"Erro: o conjunto '{input_set}' não possui a referência paralela com uma thread."
            )

        sequential_median = median(sequential[input_set])
        threads = sorted(parallel[input_set])
        parallel_medians = [median(parallel[input_set][count]) for count in threads]
        parallel_one_median = median(parallel[input_set][1])
        scaling_speedups = [parallel_one_median / elapsed for elapsed in parallel_medians]
        scaling_efficiencies = [
            speedup / count for speedup, count in zip(scaling_speedups, threads)
        ]
        baseline_speedups = [sequential_median / elapsed for elapsed in parallel_medians]
        population, bits, generations, mutation_rate, seed = metadata[input_set]

        svg_chart(
            arguments.output_dir / f"speedup_{slugify(input_set)}.svg",
            f"Speedup de escalabilidade - conjunto {input_set}", "Speedup S(p)", threads,
            scaling_speedups, threads, "Medido",
        )
        svg_chart(
            arguments.output_dir / f"eficiencia_{slugify(input_set)}.svg",
            f"Eficiência - conjunto {input_set}", "Eficiência E(p)", threads,
            scaling_efficiencies, [1.0] * len(threads), "Medida",
        )

        for count, parallel_median, scaling_speedup, scaling_efficiency, baseline_speedup in zip(
            threads, parallel_medians, scaling_speedups, scaling_efficiencies, baseline_speedups
        ):
            summary_rows.append({
                "input_set": input_set,
                "population": population,
                "bits": bits,
                "generations": generations,
                "mutation_rate": mutation_rate,
                "seed": seed,
                "threads": count,
                "sequential_median_seconds": f"{sequential_median:.9f}",
                "parallel_one_thread_median_seconds": f"{parallel_one_median:.9f}",
                "parallel_median_seconds": f"{parallel_median:.9f}",
                "scaling_speedup": f"{scaling_speedup:.6f}",
                "scaling_efficiency": f"{scaling_efficiency:.6f}",
                "baseline_speedup": f"{baseline_speedup:.6f}",
                "sequential_samples": len(sequential[input_set]),
                "parallel_samples": len(parallel[input_set][count]),
            })

    fieldnames = [
        "input_set", "population", "bits", "generations", "mutation_rate", "seed",
        "threads", "sequential_median_seconds", "parallel_one_thread_median_seconds",
        "parallel_median_seconds", "scaling_speedup", "scaling_efficiency",
        "baseline_speedup", "sequential_samples", "parallel_samples",
    ]
    with arguments.summary_file.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"Resumo salvo em: {arguments.summary_file}")
    print(f"Gráficos salvos em: {arguments.output_dir}")


if __name__ == "__main__":
    main()
