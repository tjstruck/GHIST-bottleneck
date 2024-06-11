#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: Score predictions file

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
    - entryname: score.py
      entry: |
        #!/usr/bin/env python
        import argparse
        import json
        parser = argparse.ArgumentParser()
        parser.add_argument("-f", "--submissionfile", required=True, help="Submission File")
        parser.add_argument("-r", "--results", required=True, help="Scoring results")
        parser.add_argument("-g", "--goldstandard", required=True, help="Goldstandard for scoring")

        args = parser.parse_args()

        import yaml
        import numpy as np
        def relative_root_mean_squared_error(true, pred):
            n = len(true) # update
            num = np.sum(np.square(true - pred)) / n  # update
            den = np.sum(np.square(pred))
            squared_error = num/den
            rrmse_loss = np.sqrt(squared_error)
            return rrmse_loss

        exc = 'No error'
        with open(args.submissionfile) as stream:
            try:
                submission = yaml.safe_load(stream)
            except yaml.YAMLError as exc:
                print(exc)


        exc = 'No error'
        with open(args.goldstandard) as stream:
            try:
                goldstandard = yaml.safe_load(stream)
            except yaml.YAMLError as exc:
                print(exc)

        keys = goldstandard['parameters']
        keys.sort()
        RRMSE = relative_root_mean_squared_error(np.array([goldstandard['parameters'][key] for key in keys]), np.array([submission['parameters'][key] for key in keys]))
        prediction_file_status = "SCORED"

        result = {'rrmse': RRMSE,
                  'submission_status': prediction_file_status}
        with open(args.results, 'w') as o:
          o.write(json.dumps(result))

inputs:
  - id: input_file
    type: File
  - id: goldstandard
    type: File
  - id: check_validation_finished
    type: boolean?

outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json
  - id: status
    type: string
    outputBinding:
      glob: results.json
      outputEval: $(JSON.parse(self[0].contents)['submission_status'])
      loadContents: true

baseCommand: python
arguments:
  - valueFrom: score.py
  - prefix: -f
    valueFrom: $(inputs.input_file.path)
  - prefix: -g
    valueFrom: $(inputs.goldstandard.path)
  - prefix: -r
    valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: tjstruck/popsim-pilot-slim:1.32