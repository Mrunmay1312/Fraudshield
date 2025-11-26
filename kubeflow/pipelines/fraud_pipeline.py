import argparse
from kfp import dsl
from kfp import compiler

# -----------------------------------------------------------
# Components (replace container images with your final ones)
# -----------------------------------------------------------

@dsl.container_component
def preprocess_op():
    return dsl.ContainerSpec(
        image="python:3.9",
        command=["python", "-c"],
        args=["print('Preprocessing step executed')"]
    )

@dsl.container_component
def train_op():
    return dsl.ContainerSpec(
        image="python:3.9",
        command=["python", "-c"],
        args=["print('Training step executed')"]
    )

@dsl.container_component
def evaluate_op():
    return dsl.ContainerSpec(
        image="python:3.9",
        command=["python", "-c"],
        args=["print('Evaluation step executed')"]
    )

@dsl.pipeline(
    name="Fraud Detection Pipeline",
    description="End-to-end fraud model training pipeline"
)
def fraud_pipeline():
    preprocess_task = preprocess_op()
    train_task = train_op()
    train_task.after(preprocess_task)
    evaluate_task = evaluate_op()
    evaluate_task.after(train_task)

# -----------------------------------------------------------
# CLI to compile pipeline
# -----------------------------------------------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--compile",
        action="store_true",
        help="Compile the pipeline to fraud_pipeline.yaml"
    )
    args = parser.parse_args()

    if args.compile:
        compiler.Compiler().compile(
            pipeline_func=fraud_pipeline,
            package_path="fraud_pipeline.yaml"
        )
        print("Pipeline compiled → fraud_pipeline.yaml")

