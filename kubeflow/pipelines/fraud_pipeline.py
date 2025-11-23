import kfp
from kfp import dsl
def preprocess_op():
    return dsl.ContainerOp(
        name='preprocess',
        image='python:3.10-slim',
        command=['bash','-c'],
        arguments=['python - <<PY\nimport joblib, numpy as np\nX=np.random.rand(500,10)\ny=(X.sum(axis=1)>5).astype(int)\njoblib.dump((X,y),"/tmp/dataset.joblib")\nprint(\"done\")\nPY'],
        file_outputs={'dataset':'/tmp/dataset.joblib'}
    )
def train_op(dataset):
    return dsl.ContainerOp(
        name='train',
        image='python:3.10-slim',
        command=['bash','-c'],
        arguments=['python - <<PY\nimport joblib\nfrom sklearn.ensemble import RandomForestClassifier\nX,y=joblib.load("'+dataset+'")\nclf=RandomForestClassifier(n_estimators=20)\nclf.fit(X,y)\njoblib.dump(clf,"/tmp/model.joblib")\nprint(\"trained\")\nPY'],
        file_outputs={'model':'/tmp/model.joblib'}
    )
def evaluate_op(model, dataset):
    return dsl.ContainerOp(
        name='evaluate',
        image='python:3.10-slim',
        command=['bash','-c'],
        arguments=['python - <<PY\nimport joblib\nmodel=joblib.load("'+model+'")\nX,y=joblib.load("'+dataset+'")\nprint(model.score(X,y))\nPY']
    )
@dsl.pipeline(name='fraud-pipeline-poc', description='POC pipeline')
def fraud_pipeline():
    p = preprocess_op()
    t = train_op(p.outputs['dataset'])
    _ = evaluate_op(t.outputs['model'], p.outputs['dataset'])
if __name__=='__main__':
    kfp.compiler.Compiler().compile(fraud_pipeline, 'fraud_pipeline.yaml')
